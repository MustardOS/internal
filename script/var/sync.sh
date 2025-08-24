#!/bin/sh

# Source newer than destination (or it's missing?)
IS_NEWER() {
	SRC="$1"
	DST="$2"

	[ -f "$DST" ] || return 0

	find "$SRC" -prune -newer "$DST" -print -quit 2>/dev/null | grep -q .
}

# Source is older than destination (or it's missing?)
IS_OLDER() {
	SRC="$1"
	DST="$2"

	[ -f "$DST" ] || return 0

	find "$DST" -prune -newer "$SRC" -print -quit 2>/dev/null | grep -q .
}

# Comma option finder: HAS_OPT <name> <comma,list,of,opts>
HAS_OPT() {
	NAME="$1"
	LIST="$2"

	case ",$LIST," in
		*,"$NAME",*) return 0 ;;
		*) return 1 ;;
	esac
}

# Safe quick writability probe (opts: use only if you want a guard...)
DIR_WRITABLE() {
	D="$1"
	T="$D/.swt_$$" # Sync Write Test!

	(: >"$T") 2>/dev/null && {
		rm -f "$T"
		return 0
	}

	return 1
}

DO_COPY() {
	SRC="$1"
	DST="$2"
	OPTS="$3"

	if HAS_OPT "guard" "$OPTS"; then
		DIR="${DST%/*}"
		[ "$DIR" = "$DST" ] && DIR="."
		DIR_WRITABLE "$DIR" || return 4
	fi

	if HAS_OPT "backup" "$OPTS" && [ -f "$DST" ]; then
		mv -f "$DST" "$DST.bak" 2>/dev/null || return 3
	fi

	if HAS_OPT "dryrun" "$OPTS"; then
		return 0
	fi

	if HAS_OPT "atomic" "$OPTS"; then
		TMP="$DST.tmp.$$"
		cp -f "$SRC" "$TMP" 2>/dev/null || {
			rm -f "$TMP"
			return 3
		}
		mv -f "$TMP" "$DST" 2>/dev/null || {
			rm -f "$TMP"
			return 3
		}
	else
		cp -f "$SRC" "$DST" 2>/dev/null || return 3
	fi

	HAS_OPT "preserve" "$OPTS" && touch -r "$SRC" "$DST" 2>/dev/null

	if HAS_OPT "verify" "$OPTS"; then
		cmp -s "$SRC" "$DST" 2>/dev/null || return 3
	fi

	return 0
}

# FILE_OK <mode> <path>
# <mode> is either checking for "size" (size > 0) or anything else
FILE_OK() {
	MODE="$1"
	FILE="$2"

	case "$MODE" in
		size) [ -s "$FILE" ] ;;
		*) [ -s "$FILE" ] && grep -q '[^[:space:]]' "$FILE" 2>/dev/null ;;
	esac
}

# SYNC_FILE <SRC_ROOT> <DST_ROOT> <REL_PATH> [mode] [opts]
# mode: content (default) | size | overwrite | newer | older
# opts: comma list from {atomic,verify,preserve,backup,dryrun,guard}
# returns: 0 ok, 1 mkdir fail, 2 no valid source, 3 copy or verify fail, 4 not writable
SYNC_FILE() {
	SRC_ROOT="$1"
	DST_ROOT="$2"
	REL_PATH="$3"

	MODE="${4:-content}"
	OPTS="${5:-}"

	SRC="$SRC_ROOT/$REL_PATH"
	DST="$DST_ROOT/$REL_PATH"
	case "$DST" in */*) DST_DIR="${DST%/*}" ;; *) DST_DIR="." ;; esac

	[ -d "$DST_DIR" ] || mkdir -p "$DST_DIR" || return 1
	[ -f "$SRC" ] || return 2

	case "$MODE" in
		overwrite)
			DO_COPY "$SRC" "$DST" "$OPTS" || return $?
			return 0
			;;
		newer)
			[ ! -f "$DST" ] || IS_NEWER "$SRC" "$DST" || return 0
			[ -f "$DST" ] && cmp -s "$SRC" "$DST" 2>/dev/null && return 0
			DO_COPY "$SRC" "$DST" "$OPTS" || return $?
			return 0
			;;
		older)
			[ ! -f "$DST" ] || IS_OLDER "$SRC" "$DST" || return 0
			[ -f "$DST" ] && cmp -s "$SRC" "$DST" 2>/dev/null && return 0
			DO_COPY "$SRC" "$DST" "$OPTS" || return $?
			return 0
			;;
		size | content | *)
			FILE_OK "$MODE" "$DST" && return 0
			FILE_OK "$MODE" "$SRC" || return 2
			[ -f "$DST" ] && cmp -s "$SRC" "$DST" 2>/dev/null && return 0
			DO_COPY "$SRC" "$DST" "$OPTS" || return $?
			return 0
			;;
	esac
}
