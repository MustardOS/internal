#!/bin/sh

[ -n "${MUOS_LOG_LOADED-}" ] && return 0
MUOS_LOG_LOADED=1
[ -n "${MUOS_CONFIG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/config.sh"

PARSE_INI() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"

	sed -n "/^\[$SECTION\]/ { :l /^${KEY}[ ]*=[ ]*/ { s/^[^=]*=[ ]*//; p; q; }; n; b l; }" "${INI_FILE}"
}

GET_DEBUG() {
	DEBUG_MODE=0

	[ -r "$MUOS_CONF_SYSTEM/debug_mode" ] && {
		IFS= read -r DEBUG_MODE <"$MUOS_CONF_SYSTEM/debug_mode" 2>/dev/null
	}

	DEBUG_MODE=${DEBUG_MODE%"$CR"}

	case "$DEBUG_MODE" in
		''|*[!0-9]*)
			DEBUG_MODE=0
			;;
	esac

	printf "%d" "$DEBUG_MODE"
}

if [ "$(GET_DEBUG)" -gt 0 ]; then
	LOG_INFO() {
		"$MUOS_LOG_BIN" info "$@"
	}

	LOG_WARN() {
		"$MUOS_LOG_BIN" warn "$@"
	}

	LOG_ERROR() {
		"$MUOS_LOG_BIN" error "$@"
	}

	LOG_SUCCESS() {
		"$MUOS_LOG_BIN" success "$@"
	}

	LOG_DEBUG() {
		"$MUOS_LOG_BIN" debug "$@"
	}
else
	LOG_INFO() { :; }
	LOG_WARN() { :; }
	LOG_ERROR() { :; }
	LOG_SUCCESS() { :; }
	LOG_DEBUG() { :; }
fi

CRITICAL_FAILURE() {
	case "$1" in
		mount) MESSAGE=$(printf "Mount Failure\n\n%s" "$2") ;;
		format) MESSAGE=$(printf "Format Failure\n\nCould not create a %s filesystem on %s" "$3" "$2") ;;
		udev) MESSAGE=$(printf "Critical Failure\n\nFailed to initialise udev!") ;;
		*) MESSAGE=$(printf "Critical Failure\n\nAn unknown error occurred!") ;;
	esac

	/opt/muos/frontend/muxmessage 0 "$MESSAGE"
	sleep 10
	/opt/muos/script/system/halt.sh poweroff
}

