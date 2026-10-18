#!/bin/sh

[ -n "${MUOS_CONFIG_LOADED-}" ] && return 0
MUOS_CONFIG_LOADED=1
[ -n "${MUOS_BASE_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/base.sh"

CR=$(printf '\r')

VALID_VAR_PATH() {
	case "${1:-}" in
		"" | /* | */../* | ../* | */.. | .. | *//* | *[!A-Za-z0-9_./-]*) return 1 ;;
		*) return 0 ;;
	esac
}

SET_VAR() {
	case "$1" in
		GLOBAL | global | CONFIG | config) NS=global ;;
		DEVICE | device) NS=device ;;
		KIOSK | kiosk) NS=kiosk ;;
		SYSTEM | system) NS=system ;;
		*) return 1 ;;
	esac

	VALID_VAR_PATH "$2" || return 1

	[ -x "$MUOS_VAR_BIN" ] && {
		"$MUOS_VAR_BIN" set "$NS" "$2" "$3"
		return $?
	}

	SET_VAR_DIRECT "$1" "$2" "$3"
}

SET_VAR_DIRECT() {
	BASE=
	case "$1" in
		GLOBAL | global | CONFIG | config) BASE=$MUOS_CONF_GLOBAL ;;
		DEVICE | device) BASE=$MUOS_CONF_DEVICE ;;
		KIOSK | kiosk) BASE=$MUOS_CONF_KIOSK ;;
		SYSTEM | system) BASE=$MUOS_CONF_SYSTEM ;;
	esac

	[ -n "$BASE" ] || return 1
	VALID_VAR_PATH "$2" || return 1

	VAR_DIR=${2%/*}
	[ "$VAR_DIR" = "$2" ] && VAR_DIR=.
	[ -d "$BASE/$VAR_DIR" ] || return 1

	TMP="${BASE}/${2}.tmp.$$"
	if ! { printf "%s" "$3" >"$TMP" && mv -f "$TMP" "$BASE/$2"; }; then
		rm -f "$TMP"
		return 1
	fi
}

SET_VAR_DURABLE() {
	case "$1" in
		GLOBAL | global | CONFIG | config) NS=global ;;
		DEVICE | device) NS=device ;;
		KIOSK | kiosk) NS=kiosk ;;
		SYSTEM | system) NS=system ;;
		*) return 1 ;;
	esac

	VALID_VAR_PATH "$2" || return 1

	if [ -x "$MUOS_VAR_BIN" ] && "$MUOS_VAR_BIN" set --durable "$NS" "$2" "$3" 2>/dev/null; then
		return 0
	fi

	SET_VAR_DIRECT "$1" "$2" "$3" || return 1
	sync
}

GET_VAR() {
	BASE=
	case "$1" in
		GLOBAL | global | CONFIG | config) BASE=$MUOS_CONF_GLOBAL ;;
		DEVICE | device) BASE=$MUOS_CONF_DEVICE ;;
		KIOSK | kiosk) BASE=$MUOS_CONF_KIOSK ;;
		SYSTEM | system) BASE=$MUOS_CONF_SYSTEM ;;
	esac

	[ -n "$BASE" ] || return 1
	VALID_VAR_PATH "$2" || return 1

	FILE="$BASE/$2"
	[ -r "$FILE" ] || return 0

	VAL=
	IFS= read -r VAL <"$FILE"

	VAL=${VAL%"$CR"}

	printf "%s" "$VAL"
}

DEL_VAR() {
	BASE=
	case "$1" in
		GLOBAL | global | CONFIG | config) BASE=$MUOS_CONF_GLOBAL ;;
		DEVICE | device) BASE=$MUOS_CONF_DEVICE ;;
		KIOSK | kiosk) BASE=$MUOS_CONF_KIOSK ;;
		SYSTEM | system) BASE=$MUOS_CONF_SYSTEM ;;
	esac

	[ -n "$BASE" ] || return 1

	case "$2" in
		*/*)
			DIR=${2%/*}
			PATTERN=${2##*/}
			;;
		*)
			DIR=.
			PATTERN=$2
			;;
	esac

	VALID_VAR_PATH "$DIR" || return 1
	case "$PATTERN" in
		\**) ;;
		*) VALID_VAR_PATH "$PATTERN" || return 1 ;;
	esac
	FULL_DIR="$BASE/$DIR"

	[ -d "$FULL_DIR" ] || return 0

	case "$PATTERN" in
		\**)
			EXCL_SPEC="${PATTERN#\*}"
			EXCLUDES=

			if [ -n "$EXCL_SPEC" ]; then
				OLD_IFS="$IFS"
				IFS='|'
				for TOKEN in $EXCL_SPEC; do
					EXCLUDES="$EXCLUDES ${TOKEN#!}"
				done
				IFS="$OLD_IFS"
			fi

			for FILE in "$FULL_DIR"/*; do
				[ -f "$FILE" ] || continue
				FNAME=${FILE##*/}

				SKIP=0
				for EXCL in $EXCLUDES; do
					[ "$FNAME" = "$EXCL" ] && SKIP=1 && break
				done

				[ "$SKIP" -eq 0 ] && {
					rm -f "$FILE"
					if [ "$DIR" = "." ]; then
						DROP_VAR "$1" "$FNAME"
					else
						DROP_VAR "$1" "$DIR/$FNAME"
					fi
				}
			done
			;;
		*)
			rm -f "$FULL_DIR/$PATTERN"
			DROP_VAR "$1" "$2"
			;;
	esac
}

DROP_VAR() {
	[ -x "$MUOS_VAR_BIN" ] || return 0

	case "$1" in
		GLOBAL | global | CONFIG | config) NS=global ;;
		DEVICE | device) NS=device ;;
		KIOSK | kiosk) NS=kiosk ;;
		SYSTEM | system) NS=system ;;
		*) return 0 ;;
	esac

	"$MUOS_VAR_BIN" del "$NS" "$2" 2>/dev/null || return 0
}

