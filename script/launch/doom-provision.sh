#!/bin/sh
# Work out what to run from a ".doom" folder and stage it for prboom.
#
# The folder is the content, so a user only has to drop the game's files into
# "Doom 2.doom" and go. Everything needed is discovered here: the IWAD, any patch WADs
# and any DeHackEd patches. prboom is then handed an anchor WAD of its own with a
# generated prboom.cfg beside it, which keeps save states separate per folder.
#
# A folder that already carries a hand written runner keeps working exactly as before,
# including the old ".WAD" subdirectory, so nothing that used to launch stops launching.
#
# Usage: doom-provision.sh <content folder> <name> [log path]
# Prints the path of the WAD to launch on success.

. /opt/muos/script/var/func.sh

DP_DIR=${1%/}
DP_NAME=$2
DP_LOG=${3:-/dev/null}

DP_LOG_LINE() {
	printf '%s\n' "$1" >>"$DP_LOG"
}

DP_FAIL() {
	DP_LOG_LINE "ERROR: $1"
	printf '%s\n' "$1" >&2
	exit 1
}

[ -n "$DP_DIR" ] && [ -d "$DP_DIR" ] || DP_FAIL "Content folder not found"
[ -n "$DP_NAME" ] || DP_FAIL "Content name not given"

DP_RUNNER="$DP_DIR/$DP_NAME.doom"
DP_WORK="$DP_DIR/.$DP_NAME"
DP_CFG="$DP_WORK/prboom.cfg"
DP_ANCHOR="$DP_WORK/${DP_NAME}_prboom.wad"
DP_BIOS="$MUOS_STORE_DIR/bios/prboom.wad"

mkdir -p "$DP_WORK" || DP_FAIL "Cannot create work directory"

# IWADs are the retail or freeware base games. prboom needs exactly one, and it has to be
# listed first so the patch WADs load on top of it.
DP_IS_IWAD() {
	case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
		doom.wad | doom1.wad | doom2.wad | doomu.wad | tnt.wad | plutonia.wad | \
			freedoom1.wad | freedoom2.wad | freedm.wad | \
			heretic.wad | heretic1.wad | hexen.wad | hexdd.wad | \
			chex.wad | chex3.wad | hacx.wad | strife1.wad | strife0.wad) return 0 ;;
		*) return 1 ;;
	esac
}

# Link rather than copy. An IWAD runs to tens of megabytes and the files are already
# sitting in the folder, so there is nothing to gain from a second copy on the card.
DP_STAGE() {
	[ -e "$DP_WORK/$(basename "$1")" ] || ln -sf "../$(basename "$1")" "$DP_WORK/$(basename "$1")"
}

DP_LEGACY_RUNNER() {
	[ -s "$DP_RUNNER" ] || return 1
	grep -qiE '^[[:space:]]*(parentwad|wadfile_|dehfile_)' "$DP_RUNNER" 2>/dev/null
}

if DP_LEGACY_RUNNER; then
	DP_LOG_LINE "Using existing runner: $DP_RUNNER"

	# Compensate for Windows wild cuntery
	dos2unix -n "$DP_RUNNER" "$DP_RUNNER" 2>/dev/null

	DP_WAD_DIR="$DP_DIR/.WAD"
	[ -d "$DP_WAD_DIR" ] || DP_WAD_DIR="$DP_DIR"

	while IFS='"' read -r DP_KEY DP_VALUE _; do
		case "$DP_KEY" in
			*parentwad* | *wadfile_* | *dehfile_*)
				[ -n "$DP_VALUE" ] || continue
				if [ -f "$DP_WAD_DIR/$DP_VALUE" ]; then
					[ -e "$DP_WORK/$DP_VALUE" ] ||
						ln -sf "$DP_WAD_DIR/$DP_VALUE" "$DP_WORK/$DP_VALUE"
				else
					DP_LOG_LINE "WARN: listed file missing: $DP_VALUE"
				fi
				;;
			*) ;;
		esac
	done <"$DP_RUNNER"

	cp -f "$DP_RUNNER" "$DP_CFG" || DP_FAIL "Cannot write prboom configuration"
else
	DP_LOG_LINE "Discovering content in: $DP_DIR"

	DP_IWAD=""
	DP_PWADS=""
	DP_DEHS=""

	for DP_FILE in "$DP_DIR"/*; do
		[ -f "$DP_FILE" ] || continue
		DP_BASE=$(basename "$DP_FILE")

		case "$(printf '%s' "$DP_BASE" | tr '[:upper:]' '[:lower:]')" in
			*.wad)
				if DP_IS_IWAD "$DP_BASE" && [ -z "$DP_IWAD" ]; then
					DP_IWAD=$DP_BASE
				else
					DP_PWADS="$DP_PWADS$DP_BASE
"
				fi
				;;
			*.deh | *.bex) DP_DEHS="$DP_DEHS$DP_BASE
" ;;
			*) ;;
		esac
	done

	# With no recognised IWAD name, the largest WAD present is the best remaining guess:
	# a base game is always substantially bigger than a patch for it.
	if [ -z "$DP_IWAD" ]; then
		DP_IWAD=$(printf '%s' "$DP_PWADS" | while IFS= read -r DP_W || [ -n "$DP_W" ]; do
			[ -n "$DP_W" ] || continue
			printf '%s %s\n' "$(wc -c <"$DP_DIR/$DP_W" 2>/dev/null || echo 0)" "$DP_W"
		done | sort -rn | head -1 | cut -d' ' -f2-)

		[ -n "$DP_IWAD" ] && DP_PWADS=$(printf '%s' "$DP_PWADS" | grep -vxF "$DP_IWAD")
		[ -n "$DP_IWAD" ] && DP_LOG_LINE "No known IWAD name, using largest WAD: $DP_IWAD"
	fi

	[ -n "$DP_IWAD" ] || DP_FAIL "No WAD files found in $(basename "$DP_DIR")"

	DP_LOG_LINE "IWAD: $DP_IWAD"

	: >"$DP_CFG" || DP_FAIL "Cannot write prboom configuration"
	DP_STAGE "$DP_DIR/$DP_IWAD"
	printf 'wadfile_1\t\t"%s"\n' "$DP_IWAD" >>"$DP_CFG"

	# prboom reads wadfile_1 through wadfile_8 and dehfile_1 through dehfile_2, so the
	# lists are capped to what it will actually look at.
	DP_SLOT=2
	printf '%s' "$DP_PWADS" | while IFS= read -r DP_W || [ -n "$DP_W" ]; do
		[ -n "$DP_W" ] || continue
		[ "$DP_SLOT" -le 8 ] || break
		DP_STAGE "$DP_DIR/$DP_W"
		printf 'wadfile_%d\t\t"%s"\n' "$DP_SLOT" "$DP_W" >>"$DP_CFG"
		DP_SLOT=$((DP_SLOT + 1))
	done

	DP_SLOT=1
	printf '%s' "$DP_DEHS" | while IFS= read -r DP_D || [ -n "$DP_D" ]; do
		[ -n "$DP_D" ] || continue
		[ "$DP_SLOT" -le 2 ] || break
		DP_STAGE "$DP_DIR/$DP_D"
		printf 'dehfile_%d\t\t"%s"\n' "$DP_SLOT" "$DP_D" >>"$DP_CFG"
		DP_SLOT=$((DP_SLOT + 1))
	done

	DP_LOG_LINE "Generated $DP_CFG"
fi

[ -f "$DP_BIOS" ] || DP_FAIL "Missing prboom.wad in bios directory"
cp -f "$DP_BIOS" "$DP_ANCHOR" || DP_FAIL "Cannot stage prboom anchor WAD"

printf '%s\n' "$DP_ANCHOR"
