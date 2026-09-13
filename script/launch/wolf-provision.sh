#!/bin/sh
# Work out what to run from a ".wolf" folder and stage it for ecwolf.
#
# The folder is the content, so dropping a Wolfenstein 3D data set into "Wolf3D.wolf" is
# all that is needed. ecwolf locates a game by scanning a directory for its base data
# (*.wl6, *.wl1, *.sdm, *.sod, *.n3d), so the files are linked into a work directory and
# ecwolf is pointed at an anchor beside them. The anchor keeps save data per folder.
#
# A folder that already carries a hand written runner keeps working as before.
#
# Usage: wolf-provision.sh <content folder> <name> [log path]
# Prints the path of the anchor to launch on success.

. /opt/muos/script/var/func.sh

WP_DIR=${1%/}
WP_NAME=$2
WP_LOG=${3:-/dev/null}

WP_LOG_LINE() {
	printf '%s\n' "$1" >>"$WP_LOG"
}

WP_FAIL() {
	WP_LOG_LINE "ERROR: $1"
	printf '%s\n' "$1" >&2
	exit 1
}

[ -n "$WP_DIR" ] && [ -d "$WP_DIR" ] || WP_FAIL "Content folder not found"
[ -n "$WP_NAME" ] || WP_FAIL "Content name not given"

WP_RUNNER="$WP_DIR/$WP_NAME.wolf"
WP_WORK="$WP_DIR/.$WP_NAME"
WP_ANCHOR="$WP_WORK/$(basename "$WP_NAME").EXE"

mkdir -p "$WP_WORK" || WP_FAIL "Cannot create work directory"

# Link rather than copy so a data set is not duplicated on the card.
WP_STAGE() {
	WP_BASE=$(basename "$1")
	[ -e "$WP_WORK/$WP_BASE" ] || ln -sf "../$WP_BASE" "$WP_WORK/$WP_BASE"
}

# A runner naming a real executable is the old layout, where the data sits in a
# subdirectory rather than the folder itself.
if [ -s "$WP_RUNNER" ] && [ -f "$WP_WORK/$(tr -d '\r\n' <"$WP_RUNNER")" ]; then
	WP_LOG_LINE "Using existing runner: $WP_RUNNER"

	# Compensate for Windows wild cuntery
	dos2unix -n "$WP_RUNNER" "$WP_RUNNER" 2>/dev/null

	WP_REAL="$WP_WORK/$(tr -d '\r\n' <"$WP_RUNNER")"
	cp -f "$WP_REAL" "$WP_ANCHOR" || WP_FAIL "Cannot stage ecwolf anchor"

	printf '%s\n' "$WP_ANCHOR"
	exit 0
fi

WP_LOG_LINE "Discovering content in: $WP_DIR"

WP_FOUND=0
for WP_FILE in "$WP_DIR"/*; do
	[ -f "$WP_FILE" ] || continue

	case "$(printf '%s' "$WP_FILE" | tr '[:upper:]' '[:lower:]')" in
		*.wl6 | *.wl1 | *.sdm | *.sod | *.sd1 | *.sd2 | *.sd3 | *.n3d)
			WP_STAGE "$WP_FILE"
			WP_FOUND=$((WP_FOUND + 1))
			;;
		# Audio, config and add on data ride along with the base set.
		*.wl6a | *.ecwolf | *.pk3 | *.bmp | *.cfg)
			WP_STAGE "$WP_FILE"
			;;
		*) ;;
	esac
done

[ "$WP_FOUND" -gt 0 ] ||
	WP_FAIL "No game data (*.wl6, *.wl1, *.sdm, *.sod, *.n3d) in $(basename "$WP_DIR")"

WP_LOG_LINE "Staged $WP_FOUND base data file(s)"

# ecwolf only needs the anchor to exist so it can resolve the directory and keep saves
# separate. Prefer a real executable from the data set when one is present.
WP_EXE=""
for WP_FILE in "$WP_DIR"/*; do
	[ -f "$WP_FILE" ] || continue
	case "$(printf '%s' "$WP_FILE" | tr '[:upper:]' '[:lower:]')" in
		*.exe) WP_EXE=$WP_FILE; break ;;
		*) ;;
	esac
done

if [ -n "$WP_EXE" ]; then
	cp -f "$WP_EXE" "$WP_ANCHOR" || WP_FAIL "Cannot stage ecwolf anchor"
else
	: >"$WP_ANCHOR" || WP_FAIL "Cannot stage ecwolf anchor"
fi

printf '%s\n' "$WP_ANCHOR"
