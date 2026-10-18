#!/bin/sh

[ -n "${MUOS_STAGE_LOADED-}" ] && return 0
MUOS_STAGE_LOADED=1
[ -n "${MUOS_CONFIG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/config.sh"

SETUP_STAGE_OVERLAY() {
	# Disable any stage overlay system for Console Mode, sorry not sorry!
	[ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ] && return 0

	[ "$(GET_VAR "config" "settings/advanced/stage_overlay")" -eq 0 ] && return 0

	[ -z "${MUX_LIB-}" ] && return 0
	STAGE_LIB="$MUX_LIB/libmustage.so"

	# LD_PRELOAD is space separated!
	case " ${LD_PRELOAD-} " in
		*" $STAGE_LIB "*) return 0 ;;
	esac

	if [ -n "${LD_PRELOAD-}" ]; then
		LD_PRELOAD="$STAGE_LIB $LD_PRELOAD"
	else
		LD_PRELOAD="$STAGE_LIB"
	fi

	export LD_PRELOAD
}

