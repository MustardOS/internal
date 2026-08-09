#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/nxengine.log"

printf "Starting Cave Story (libretro)\n" >"$LOGPATH"
DOUK_BIOS="$MUOS_STORE_DIR/bios/nxengine/Doukutsu.exe"

GREENLIGHT=0
if /opt/muos/script/launch/nxengine-provision.sh "$LOGPATH"; then
	GREENLIGHT=1
else
	printf "Cave Story data is unavailable\n" >>"$LOGPATH"
fi

if [ "$GREENLIGHT" -eq 1 ]; then
	IS_SWAP=$(DETECT_CONTROL_SWAP)

	printf "Launching Cave Story\n" >>"$LOGPATH"

	set -- -v -f
	[ -n "$RA_ARGS" ] && set -- "$@" "$RA_ARGS"
	retroarch "$@" -L "$MUOS_SHARE_DIR/core/nxengine_libretro.so" "$DOUK_BIOS"

	[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
fi
