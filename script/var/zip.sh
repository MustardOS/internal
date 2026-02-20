#!/bin/sh

# Extraction buffer just in case!
SPACE_BUFFER_BYTES="${SPACE_BUFFER_BYTES:-67108864}" # 64 MiB
SPACE_BUFFER_PCT="${SPACE_BUFFER_PCT:-5}"            # 5%

THROBBER_USEC="${THROBBER_USEC:-250000}"
THROBBER() {
	_PID="$1"
	while kill -0 "$_PID" 2>/dev/null; do
		printf '.'
		usleep "$THROBBER_USEC"
	done
}

ARCHIVE_LIST_CACHE_ARCHIVE=""
ARCHIVE_LIST_CACHE_FILE=""

ARCHIVE_CACHE_ARCHIVE=""
ARCHIVE_CACHE_FILE=""

CACHE_ARCHIVE_LIST() {
	ARCH="$1"

	[ "$ARCHIVE_LIST_CACHE_ARCHIVE" = "$ARCH" ] &&
		[ -n "${ARCHIVE_LIST_CACHE_FILE:-}" ] &&
		[ -s "$ARCHIVE_LIST_CACHE_FILE" ] && return 0

	ARCHIVE_LIST_CACHE_FILE="/tmp/unzip_list.$$.txt"
	ARCHIVE_LIST_CACHE_ARCHIVE="$ARCH"

	unzip -l "$ARCH" >"$ARCHIVE_LIST_CACHE_FILE" 2>/dev/null || {
		: >"$ARCHIVE_LIST_CACHE_FILE"
		return 1
	}
}

CACHE_ARCHIVE() {
	ARCH="$1"

	[ "$ARCHIVE_CACHE_ARCHIVE" = "$ARCH" ] &&
		[ -n "${ARCHIVE_CACHE_FILE:-}" ] &&
		[ -s "$ARCHIVE_CACHE_FILE" ] && return 0

	ARCHIVE_CACHE_FILE="/tmp/unzip_cache.$$.txt"
	ARCHIVE_CACHE_ARCHIVE="$ARCH"

	unzip -Z1 "$ARCH" >"$ARCHIVE_CACHE_FILE" 2>/dev/null || {
		: >"$ARCHIVE_CACHE_FILE"
		return 1
	}
}

GET_TOP_LEVEL_DIRS() {
	ARCH="$1"
	CACHE_ARCHIVE "$ARCH" || return 1

	awk -F/ 'NF>1 {print $1}' "$ARCHIVE_CACHE_FILE" | sort -u
}

BYTES_FREE() {
	P="$1"

	while [ ! -e "$P" ] && [ "$P" != "/" ]; do
		P="${P%/*}"
	done

	AVAIL_KB="$(df -Pk "$P" 2>/dev/null | awk 'NR==2{print $4}')"
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
	ARCH="$1"
	PREFIX="${2:-}"

	CACHE_ARCHIVE_LIST "$ARCH" >/dev/null 2>&1 || {
		printf %s 0
		return 0
	}

	if [ -n "$PREFIX" ]; then
		awk -v p="$PREFIX" 'NR>3 && $1 ~ /^[0-9]+$/ { name=$NF; if (index(name,p)==1) sum+=$1 } END{print sum+0}' "$ARCHIVE_LIST_CACHE_FILE"
	else
		awk 'NR>3 && $1 ~ /^[0-9]+$/ {sum+=$1} END{print sum+0}' "$ARCHIVE_LIST_CACHE_FILE"
	fi
}

RESOLVE_ARCHIVE_BIND_PATH() {
	BINDMAP="$MUOS_STORE_DIR/bindmap"
	ARCHIVE_ROOT="$1"

	if [ -r "$BINDMAP" ]; then
		awk -F'|' -v k="$ARCHIVE_ROOT" '$1 == k { print $3; exit }' "$BINDMAP"
	fi
}

CHECK_SPACE_FOR_DEST() {
	REQ="${1:-0}"
	ROOT="$2"

	BIND="$(RESOLVE_ARCHIVE_BIND_PATH "$ROOT")"

	[ -n "$BIND" ] || {
		printf "\nError: No bind map entry for '%s'\n" "$ROOT"
		return 1
	}

	NEED="$(REQUIRED_WITH_BUFFER "$REQ")"
	HAVE="$(BYTES_FREE "$BIND")"

	if [ "$HAVE" -lt "$NEED" ]; then
		printf "\nError: Not enough free space on '%s'\nNeed %s bytes, have %s bytes!\n" "$ROOT" "$NEED" "$HAVE"
		printf "Target: %s\n" "$BIND"
		return 1
	fi

	return 0
}

CORRECT_PATH_ARCHIVE() {
	CACHE_ARCHIVE "$1" >/dev/null 2>&1 || return 1
	grep -q -E "^($2|$3)" "$ARCHIVE_CACHE_FILE"
}

SAFE_ARCHIVE() {
	CACHE_ARCHIVE "$1" >/dev/null 2>&1 || {
		printf "\nError: Cannot read archive!\n"
		return 1
	}

	if grep -E -q '^/|(^|/)\.\.(/|$)' "$ARCHIVE_CACHE_FILE"; then
		printf "\nError: Archive contains unsafe paths (absolute or '..')\n" # Damn sith!
		return 1
	fi
}

CAT_GRID_CLEAR() {
	EXTRA_DIRS="Application Archive Collection Folder Root Task Theme"
	for CAT_TYPE in $EXTRA_DIRS; do
		if CORRECT_PATH_ARCHIVE "$1" "run/muos/storage/info/catalogue/${CAT_TYPE}/grid/" "catalogue/${CAT_TYPE}/grid/"; then
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

ARC_UNSET() {
	for F in ARC_EXTRACT ARC_EXTRACT_PRE ARC_EXTRACT_POST ARC_CREATE ARC_CREATE_PRE ARC_CREATE_POST; do
		unset "$F" 2>/dev/null
	done
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

	CACHE_ARCHIVE "$ARCHIVE_PATH" >/dev/null 2>&1 || return 1

	if [ -n "$PATTERN" ]; then
		FILE_COUNT="$(unzip -Z1 "$ARCHIVE_PATH" "$PATTERN" 2>/dev/null | grep -cv '/$')"
	else
		FILE_COUNT="$(grep -cv '/$' "$ARCHIVE_CACHE_FILE" 2>/dev/null)"
	fi

	[ "${FILE_COUNT:-0}" -gt 0 ] || FILE_COUNT=1

	if [ -n "$PATTERN" ]; then
		unzip -o "$ARCHIVE_PATH" "$PATTERN" -d "$DEST_DIR" 2>&1 | awk '/:/{print}' | /opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null
	else
		unzip -o "$ARCHIVE_PATH" -d "$DEST_DIR" 2>&1 | awk '/:/{print}' | /opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null
	fi
}

CREATE_ARCHIVE() {
	# $1 = LABEL         (for display purposes)
	# $2 = DEST_FILE     (path to .muxzip or whatever)
	# $3 = SRC_MNT_PATH  (/run/muos/storage)
	# $4 = SRC_SHORTNAME (bios, package, name)
	# $5 = SRC_SUFFIX    (bios, package/catalogue, /run/muos/storage/bios, /opt/muos/share/info/config)
	# $6 = COMPRESSION   (level of compression from the archive extensions)

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

	DEST_DIR="${DEST_FILE%/*}"
	[ "$DEST_DIR" = "$DEST_FILE" ] && DEST_DIR="."

	[ -d "$DEST_DIR" ] || mkdir -p "$DEST_DIR" || {
		printf "\nCannot create destination directory: %s\n" "$DEST_DIR"
		return 1
	}

	case "$ABS_SRC_PATH" in
		"$SRC_MNT_PATH"/*)
			BASE_DIR="$SRC_MNT_PATH"
			REL_FULL="${ABS_SRC_PATH#"$SRC_MNT_PATH"/}"
			;;
		/*)
			BASE_DIR="/"
			REL_FULL="${ABS_SRC_PATH#/}"
			;;
		*)
			BASE_DIR="."
			REL_FULL="$ABS_SRC_PATH"
			;;
	esac

	case "$REL_FULL" in
		"$SRC_SHORTNAME") REL_FROM_ROOT="$SRC_SHORTNAME" ;;
		"$SRC_SHORTNAME"/*) REL_FROM_ROOT="$REL_FULL" ;;
		*)
			LAST="${REL_FULL##*/}"
			REL_FROM_ROOT="$LAST"
			BASE_DIR="${ABS_SRC_PATH%/*}"
			;;
	esac

	UPDATE_FLAG=""
	[ -e "$DEST_FILE" ] && UPDATE_FLAG="u"

	(
		cd "$BASE_DIR" || exit 2
		# shellcheck disable=SC2086
		exec zip -q -r${UPDATE_FLAG}${COMP} "$DEST_FILE" "$REL_FROM_ROOT"
	) >/dev/null 2>&1 &
	ZIP_PID=$!

	THROBBER "$ZIP_PID"
	wait "$ZIP_PID"
	RC=$?

	if [ "$RC" -ne 0 ]; then
		printf " Failure!\n"
		printf "Archive creation failed for: %s\n\n" "$LABEL"
		return 1
	fi

	printf " Complete!\n\n"
	return 0
}
