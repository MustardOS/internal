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
		echo "Error: Not enough free space on '$DEST'"
		echo "Need $NEED bytes, have $HAVE bytes!"
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
		echo "Error: Archive contains unsafe paths (absolute or '..')." # Damn sith!
		return 1
	fi
}

CAT_GRID_CLEAR() {
	EXTRA_DIRS="Application Archive Collection Folder Root Task Theme"
	for CAT_TYPE in $EXTRA_DIRS; do
		if CORRECT_PATH_ARCHIVE "$1" "run/muos/storage/info/catalogue/${CAT_TYPE}/grid/"; then
			echo "Clearing existing ${CAT_TYPE} grid images..."
			rm -rf "/run/muos/storage/info/catalogue/${CAT_TYPE}/grid"
		fi
	done
}

EXTRACT_ARCHIVE() {
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
