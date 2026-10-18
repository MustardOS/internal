#!/bin/sh

. /opt/muos/script/var/log.sh

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
ARCHIVE_WORK_DIR=""

ARCHIVE_WORKSPACE() {
	[ -n "$ARCHIVE_WORK_DIR" ] && [ -d "$ARCHIVE_WORK_DIR" ] && return 0
	ARCHIVE_WORK_DIR="$(mktemp -d /tmp/muos-archive.XXXXXX)" || return 1
	chmod 700 "$ARCHIVE_WORK_DIR" || return 1
}

ARCHIVE_CACHE_CLEANUP() {
	[ -n "$ARCHIVE_WORK_DIR" ] && [ -d "$ARCHIVE_WORK_DIR" ] && rm -rf "$ARCHIVE_WORK_DIR"
	ARCHIVE_WORK_DIR=""
	ARCHIVE_LIST_CACHE_ARCHIVE=""
	ARCHIVE_LIST_CACHE_FILE=""
	ARCHIVE_CACHE_ARCHIVE=""
	ARCHIVE_CACHE_FILE=""
}

CACHE_ARCHIVE_LIST() {
	ARCH="$1"

	[ "$ARCHIVE_LIST_CACHE_ARCHIVE" = "$ARCH" ] &&
		[ -n "${ARCHIVE_LIST_CACHE_FILE:-}" ] &&
		[ -s "$ARCHIVE_LIST_CACHE_FILE" ] && return 0

	ARCHIVE_WORKSPACE || return 1
	ARCHIVE_LIST_CACHE_FILE="$ARCHIVE_WORK_DIR/list.txt"
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

	ARCHIVE_WORKSPACE || return 1
	ARCHIVE_CACHE_FILE="$ARCHIVE_WORK_DIR/names.txt"
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
		NP="${P%/*}"
		# If no '/' was present, NP == P and stop and use "." - Pain!
		[ "$NP" = "$P" ] && {
			P="."
			break
		}
		P="$NP"
	done

	AVAIL_KB="$(df -Pk "$P" 2>/dev/null | awk 'NR==2{print $4+0}')"
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
		unzip -Zt "$1" | awk -F'[ ,]+' '{ print $3+0 }'
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
	OVR="${3-}"

	# If override provided...
	# "/some/path"  (Treat as direct path)
	# "config"      (Treat as bindmap key and resolve to its path)

	if [ -n "${OVR:-}" ]; then
		case "$OVR" in
			/*) BIND="$OVR" ;;
			*) BIND="$(RESOLVE_ARCHIVE_BIND_PATH "$OVR")" ;;
		esac
	else
		BIND="$(RESOLVE_ARCHIVE_BIND_PATH "$ROOT")"
	fi

	[ -n "${BIND:-}" ] || {
		printf "\nError: No bind map entry for '%s'\n" "${OVR:-$ROOT}"
		return 1
	}

	# Ensure REQ is an integer to avoid "bad number" if caller passes junk or empty stuff
	case "${REQ:-}" in
		'' | *[!0-9]*) REQ=0 ;;
	esac

	NEED="$(REQUIRED_WITH_BUFFER "$REQ")"
	HAVE="$(BYTES_FREE "$BIND")"

	# Ensure NEED/HAVE is actually a bloody integer too
	case "$NEED" in '' | *[!0-9]*) NEED=0 ;; esac
	case "$HAVE" in '' | *[!0-9]*) HAVE=0 ;; esac

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

	if grep -E -q '^/|^[A-Za-z]:|(^|/)\.\.(/|$)|\\' "$ARCHIVE_CACHE_FILE"; then
		if [ -n "${MUOS_LOG_BIN:-}" ] && [ -x "${MUOS_LOG_BIN}" ]; then
			grep -E '^/|^[A-Za-z]:|(^|/)\.\.(/|$)|\\' "$ARCHIVE_CACHE_FILE" | while IFS= read -r SA_LINE; do
				"$MUOS_LOG_BIN" error "$0" 0 "EXTRACT" "Unsafe path in '${1##*/}': $SA_LINE"
			done
		fi
		printf "\nError: Archive contains unsafe paths\n"
		return 1
	fi

	MAX_ENTRIES="${ARCHIVE_MAX_ENTRIES:-16384}"
	MAX_ENTRY_BYTES="${ARCHIVE_MAX_ENTRY_BYTES:-536870912}"
	MAX_TOTAL_BYTES="${ARCHIVE_MAX_TOTAL_BYTES:-2147483648}"
	MAX_RATIO="${ARCHIVE_MAX_RATIO:-1000}"

	case "$MAX_ENTRIES:$MAX_ENTRY_BYTES:$MAX_TOTAL_BYTES:$MAX_RATIO" in
		*[!0-9:]* | *::* | :* | *:) return 1 ;;
	esac

	if ! unzip -Zl "$1" 2>/dev/null | awk \
		-v max_entries="$MAX_ENTRIES" \
		-v max_entry="$MAX_ENTRY_BYTES" \
		-v max_total="$MAX_TOTAL_BYTES" \
		-v max_ratio="$MAX_RATIO" '
		$1 ~ /^[-dbclps]/ && $4 ~ /^[0-9]+$/ && $6 ~ /^[0-9]+$/ {
			type = substr($1, 1, 1)
			uncompressed = $4 + 0
			compressed = $6 + 0
			entries++
			if (type != "-" && type != "d") unsafe = 1
			if (uncompressed > max_entry) oversized = 1
			total += uncompressed
			if (compressed == 0 && uncompressed > 0) ratio = 1
			else if (compressed > 0 && uncompressed / compressed > max_ratio) ratio = 1
		}
		END {
			if (entries == 0 || entries > max_entries || total > max_total || unsafe || oversized || ratio) exit 1
		}'
	then
		printf "\nError: Archive contains links, special files or exceeds extraction limits\n"
		return 1
	fi

	return 0
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

# A plain unset only removes variables in BusyBox ash, so the hooks of one archive script used to
# stay defined for every script sourced after it. The settings hooks then ran "rm -rf $ARC_DIR"
# with the next script's ARC_DIR, which is the whole storage tree.
ARC_UNSET() {
	for F in ARC_EXTRACT ARC_EXTRACT_PRE ARC_EXTRACT_POST ARC_CREATE ARC_CREATE_PRE ARC_CREATE_POST; do
		unset -f "$F" 2>/dev/null
	done
	unset ARC_SPACE ARC_DIR ARC_LABEL SRC DEST LABEL COMP 2>/dev/null
}

# Keeps a transcript of a backup or extraction and copies it to MUOS/log/KIND on SD1 when the run fails
RUN_LOG_BEGIN() {
	RUN_LOG_KIND="$1"
	RUN_LOG_NAME="$2"
	TASK_RUN_LOG="$(mktemp /tmp/muos-runlog.XXXXXX)" || {
		TASK_RUN_LOG=""
		return 0
	}

	{
		printf 'MustardOS %s (%s) on %s\n' "$(GET_VAR "system" "version")" "$(GET_VAR "system" "build")" "$(GET_VAR "device" "board/name")"
		printf 'Started %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
		[ -n "$RUN_LOG_NAME" ] && printf 'Archive %s\n' "$RUN_LOG_NAME"
		printf '\n'
	} >"$TASK_RUN_LOG"
}

RUN_LOG_FINISH() {
	[ -n "${TASK_RUN_LOG:-}" ] && [ -f "$TASK_RUN_LOG" ] || return 0

	if [ "${1:-0}" -ne 0 ]; then
		RL_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/$RUN_LOG_KIND"
		RL_FILE="$RL_DIR/$(date '+%Y-%m-%d_%H%M%S')${RUN_LOG_NAME:+_$RUN_LOG_NAME}.txt"

		printf '\nFinished %s with exit code %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$TASK_RUN_LOG"
		if mkdir -p "$RL_DIR" && cp "$TASK_RUN_LOG" "$RL_FILE"; then
			LOG_INFO "$0" 0 "LOG" "$(printf "Failure log written to '%s'" "$RL_FILE")"
		fi
	fi

	rm -f "$TASK_RUN_LOG"
	TASK_RUN_LOG=""
}

BACKUP_MANIFEST="backup.manifest"

# One digest per section rather than per file, unzip streams a whole section in archive order in one pass
# where reading files one at a time costs a process each and is far too slow on a large backup
BACKUP_SECTION_DIGEST() {
	unzip -p "$1" "$2/*" 2>/dev/null | sha256sum | cut -d' ' -f1
}

BACKUP_SECTION_FILES() {
	unzip -Z1 "$1" 2>/dev/null | awk -v s="$2/" 'index($0, s) == 1 && substr($0, length($0)) != "/" { n++ } END { print n + 0 }'
}

# Writes the manifest into a finished backup, then moves it into place so a half written backup never
# carries the final name.  Usage: FINALISE_BACKUP PARTIAL FINAL SECTION...
FINALISE_BACKUP() {
	FB_PARTIAL="$1"
	FB_FINAL="$2"
	shift 2

	FB_WORK="$(mktemp -d /tmp/muos-backup.XXXXXX)" || return 1
	{
		printf 'format=1\n'
		printf 'type=backup\n'
		printf 'version=%s\n' "$(GET_VAR "system" "version")"
		printf 'build=%s\n' "$(GET_VAR "system" "build")"
		printf 'device=%s\n' "$(GET_VAR "device" "board/name")"
		printf 'created=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')"
		for FB_SECTION in "$@"; do
			printf 'section=%s files=%s sha256=%s\n' "$FB_SECTION" \
				"$(BACKUP_SECTION_FILES "$FB_PARTIAL" "$FB_SECTION")" \
				"$(BACKUP_SECTION_DIGEST "$FB_PARTIAL" "$FB_SECTION")"
		done
	} >"$FB_WORK/$BACKUP_MANIFEST"

	if ! (cd "$FB_WORK" && zip -q -0 "$FB_PARTIAL" "$BACKUP_MANIFEST") || ! mv -f "$FB_PARTIAL" "$FB_FINAL"; then
		rm -rf "$FB_WORK"
		return 1
	fi

	rm -rf "$FB_WORK"
	return 0
}

# Checks a backup against its manifest before anything is restored.  Returns 0 when it matches,
# 1 when the manifest is missing or broken and 2 when the contents do not match it
VERIFY_BACKUP() {
	VB_ARCHIVE="$1"
	ARCHIVE_WORKSPACE || return 1
	VB_MANIFEST="$ARCHIVE_WORK_DIR/$BACKUP_MANIFEST"

	unzip -p "$VB_ARCHIVE" "$BACKUP_MANIFEST" >"$VB_MANIFEST" 2>/dev/null || return 1
	grep -qx 'format=1' "$VB_MANIFEST" || return 1
	grep -q '^section=' "$VB_MANIFEST" || return 1

	CACHE_ARCHIVE "$VB_ARCHIVE" || return 1
	awk -F/ 'NF == 1 && $0 != "'"$BACKUP_MANIFEST"'" { exit 1 }' "$ARCHIVE_CACHE_FILE" || return 2

	VB_SECTIONS="$(sed -n 's/^section=\([^ ]*\) .*/\1/p' "$VB_MANIFEST" | sort)"
	[ "$(GET_TOP_LEVEL_DIRS "$VB_ARCHIVE")" = "$VB_SECTIONS" ] || return 2

	VB_TOTAL="$(printf '%s\n' "$VB_SECTIONS" | wc -l)"
	VB_INDEX=0

	while IFS= read -r VB_LINE; do
		case "$VB_LINE" in section=*) ;; *) continue ;; esac

		VB_SECTION="${VB_LINE#section=}"
		VB_SECTION="${VB_SECTION%% *}"
		VB_FILES="${VB_LINE#* files=}"
		VB_FILES="${VB_FILES%% *}"
		VB_SHA="${VB_LINE##* sha256=}"

		VB_INDEX=$((VB_INDEX + 1))
		TASK_DETAIL "$(printf "Checking %s" "$VB_SECTION")"
		TASK_PROGRESS "$VB_INDEX" "$VB_TOTAL"

		[ "$(BACKUP_SECTION_FILES "$VB_ARCHIVE" "$VB_SECTION")" = "$VB_FILES" ] || return 2
		[ "$(BACKUP_SECTION_DIGEST "$VB_ARCHIVE" "$VB_SECTION")" = "$VB_SHA" ] || return 2
	done <"$VB_MANIFEST"

	return 0
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
		TOTAL_BYTES="$(GET_ARCHIVE_BYTES "$ARCHIVE_PATH" "${PATTERN%/*}/")"
	else
		TOTAL_BYTES="$(GET_ARCHIVE_BYTES "$ARCHIVE_PATH")"
	fi

	[ "${TOTAL_BYTES:-0}" -gt 0 ] || TOTAL_BYTES=1

	mkdir -p "$DEST_DIR"
	printf "\nExtracting Archive: "

	if [ -n "$PATTERN" ]; then
		unzip -o "$ARCHIVE_PATH" "$PATTERN" -d "$DEST_DIR" >/dev/null 2>>"${TASK_RUN_LOG:-/dev/null}" &
		PID=$!
	else
		unzip -o "$ARCHIVE_PATH" -d "$DEST_DIR" >/dev/null 2>>"${TASK_RUN_LOG:-/dev/null}" &
		PID=$!
	fi

	while kill -0 "$PID" 2>/dev/null; do
		printf "."
		usleep "$THROBBER_USEC"
	done

	wait "$PID"
	RC=$?

	printf "\n\n"
	return "$RC"
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
	COMP="${6:-0}"

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
		exec zip -q "-r${UPDATE_FLAG}${COMP}" "$DEST_FILE" "$REL_FROM_ROOT"
	) >/dev/null 2>>"${TASK_RUN_LOG:-/dev/null}" &
	ZIP_PID=$!

	THROBBER "$ZIP_PID"
	wait "$ZIP_PID"
	RC=$?
	[ "$RC" -eq 12 ] && [ -n "$UPDATE_FLAG" ] && RC=0

	if [ "$RC" -ne 0 ]; then
		printf " Failure!\n"
		printf "Archive creation failed for: %s\n\n" "$LABEL"
		return 1
	fi

	printf " Complete!\n\n"
	return 0
}
