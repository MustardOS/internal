#!/bin/sh

# Extraction buffer just in case!
SPACE_BUFFER_BYTES="${SPACE_BUFFER_BYTES:-67108864}" # 64 MiB
SPACE_BUFFER_PCT="${SPACE_BUFFER_PCT:-5}"            # 5%

BYTES_FREE() {
	AVAIL_KB="$(df -Pk "$1" 2>/dev/null | awk 'NR==2{print $4}')"
	[ -n "${AVAIL_KB:-}" ] || AVAIL_KB=0

	printf %s "$((AVAIL_KB * 1024))"
}

MAX_NUM() {
	A="$1"
	B="$2"

	[ "$A" -ge "$B" ] && printf %s "$A" || printf %s "$B"
}

REQUIRED_WITH_BUFFER() {
	REQ="$1"
	PCT="$((REQ * SPACE_BUFFER_PCT / 100))"
	ABS="$SPACE_BUFFER_BYTES"
	BUF="$(MAX_NUM "$ABS" "$PCT")"

	printf %s "$((REQ + BUF))"
}

GET_ARCHIVE_BYTES() {
	unzip -l "$1" | awk '/ files$/ { print $1+0; exit }'
}

CHECK_SPACE_FOR_DEST() {
	REQ="$1"
	DEST="$2"
	NEED="$(REQUIRED_WITH_BUFFER "$REQ")"
	HAVE="$(BYTES_FREE "$DEST")"

	if [ "$HAVE" -lt "$NEED" ]; then
		printf "\nError: Not enough free space on '%s'\nNeed %s bytes, have %s bytes!\n" "$DEST" "$NEED" "$HAVE"
		return 1
	fi

	return 0
}

CORRECT_PATH_ARCHIVE() {
	unzip -l "$1" >/dev/null 2>&1 || return 1
	unzip -Z1 "$1" | grep -q "^$2"
}

SAFE_ARCHIVE() {
	if unzip -Z1 "$1" | grep -E -q '^/|(^|/)\.\.(/|$)'; then
		printf "\nError: Archive contains unsafe paths (absolute or '..')\n" # Damn sith!
		return 1
	fi
}

CAT_GRID_CLEAR() {
	EXTRA_DIRS="Application Archive Collection Folder Root Task Theme"
	for CAT_TYPE in $EXTRA_DIRS; do
		if CORRECT_PATH_ARCHIVE "$1" "run/muos/storage/info/catalogue/${CAT_TYPE}/grid/"; then
			printf "\nClearing existing %s grid images...\n" "$CAT_TYPE"
			rm -rf "$MUOS_STORE_DIR/info/catalogue/${CAT_TYPE}/grid"
		fi
	done
}

CHECK_ARCHIVE() {
	if unzip -Zl "$1" | awk 'NR>3 && NF>=8 {print $8}' | grep -vq '^Stored$'; then
		echo ""
		echo "WARNING: Archive was NOT created with STORE only compression"
		echo ""
		echo "Any PNGs are already compressed so deflate will just slow extracts"
		echo "Please repackage with: zip -ru0"
		echo ""
	fi
}

EXTRACT_ARCHIVE() {
	# $1 = LABEL        (for display purposes)
	# $2 = ARCHIVE_PATH (path to .muxzip or whatever)
	# $3 = DEST_DIR     (path to where we want to extract contents)
	# $4 = PATTERN      (what we want to specifically extract) (optional)

	LABEL="$1"
	ARCHIVE_PATH="$2"
	DEST_DIR="$3"
	PATTERN="${4-}"

	if [ -n "$PATTERN" ]; then
		FILE_COUNT="$(unzip -Z1 "$ARCHIVE_PATH" "$PATTERN" 2>/dev/null | grep -cv '/$' || true)"
	else
		FILE_COUNT="$(unzip -Z1 "$ARCHIVE_PATH" 2>/dev/null | grep -cv '/$' || true)"
	fi

	[ "${FILE_COUNT:-0}" -gt 0 ] || FILE_COUNT=1

	printf "Extracting %s...\n" "$LABEL"

	if [ -n "$PATTERN" ]; then
		unzip -o "$ARCHIVE_PATH" "$PATTERN" -d "$DEST_DIR" 2>/dev/null |
			grep --line-buffered -E '^ *(extracting|inflating):' |
			/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null
	else
		unzip -o "$ARCHIVE_PATH" -d "$DEST_DIR" 2>/dev/null |
			grep --line-buffered -E '^ *(extracting|inflating):' |
			/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null
	fi
}

CREATE_ARCHIVE() {
	# $1 = LABEL         (for display purposes)
	# $2 = DEST_FILE     (path to .muxzip or whatever)
	# $3 = SRC_MNT_PATH  (/run/muos/storage)
	# $4 = SRC_SHORTNAME (bios, package, name)
	# $5 = SRC_SUFFIX    (bios, package/catalogue, /run/muos/storage/bios, /opt/muos/share/info/config)

	LABEL="$1"
	DEST_FILE="$2"
	SRC_MNT_PATH="$3"
	SRC_SHORTNAME="$4"
	SRC_SUFFIX="$5"

	case "$SRC_SUFFIX" in
		/*) ABS_SRC_PATH="$SRC_SUFFIX" ;;
		*) ABS_SRC_PATH="$SRC_MNT_PATH/$SRC_SUFFIX" ;;
	esac

	if [ ! -e "$ABS_SRC_PATH" ]; then
		printf "\nSource path not found: %s\n" "$ABS_SRC_PATH"
		return 1
	fi

	DEST_DIR="$(dirname "$DEST_FILE")"
	[ -d "$DEST_DIR" ] || mkdir -p "$DEST_DIR" || {
		printf "\nCannot create destination directory: %s\n" "$DEST_DIR"
		return 1
	}

	case "$ABS_SRC_PATH" in
		"$SRC_MNT_PATH"/*) REL_FROM_ROOT="${ABS_SRC_PATH#"$SRC_MNT_PATH"/}" ;;
		/*) REL_FROM_ROOT="${ABS_SRC_PATH#/}" ;;
		*) REL_FROM_ROOT="$ABS_SRC_PATH" ;;
	esac

	LAST="${REL_FROM_ROOT##*/}"

	if command -v mktemp >/dev/null 2>&1; then
		TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/zipstage.XXXXXX")" || return 1
	else
		TMP_ROOT="${TMPDIR:-/tmp}/zipstage.$$"
		rm -rf "$TMP_ROOT" 2>/dev/null || :
		mkdir -p "$TMP_ROOT" || return 1
	fi

	# Build a minimal tree so 'zip' sees the desired archive paths starting at SRC_SHORTNAME...
	# 1) REL starts with "$SRC_SHORTNAME/..." will place symlink at that trailing path inside $SRC_SHORTNAME/
	# 2) LAST == "$SRC_SHORTNAME"             will place symlink directly as $TMP_ROOT/$SRC_SHORTNAME
	# 3) Otherwise                            will place symlink as $TMP_ROOT/$SRC_SHORTNAME/$LAST

	DIR_TRAIL="${REL_FROM_ROOT#"$SRC_SHORTNAME"/}"

	if [ "$REL_FROM_ROOT" = "$SRC_SHORTNAME" ] || [ "$LAST" = "$SRC_SHORTNAME" ]; then
		ln -s "$ABS_SRC_PATH" "$TMP_ROOT/$SRC_SHORTNAME" || {
			rm -rf "$TMP_ROOT"
			return 1
		}
	elif [ "$DIR_TRAIL" != "$REL_FROM_ROOT" ]; then
		mkdir -p "$TMP_ROOT/$SRC_SHORTNAME/$(dirname -- "$DIR_TRAIL")"
		ln -s "$ABS_SRC_PATH" "$TMP_ROOT/$SRC_SHORTNAME/$DIR_TRAIL" || {
			rm -rf "$TMP_ROOT"
			return 1
		}
	else
		mkdir -p "$TMP_ROOT/$SRC_SHORTNAME"
		ln -s "$ABS_SRC_PATH" "$TMP_ROOT/$SRC_SHORTNAME/$LAST" || {
			rm -rf "$TMP_ROOT"
			return 1
		}
	fi

	printf "Creating Archive at: '%s'\n" "$DEST_FILE"

	(
		cd "$TMP_ROOT" || exit 2
		zip -ru0 "$DEST_FILE" "$SRC_SHORTNAME"
	)
	RC=$?

	rm -rf "$TMP_ROOT"

	if [ $RC -ne 0 ]; then
		echo "Archive creation failed for: $LABEL"
		return 1
	fi

	return 0
}
