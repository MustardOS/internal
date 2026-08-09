#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "muxretro"

FRESH_ARG=""
[ -e "/tmp/ra_no_load" ] && FRESH_ARG="--fresh"

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/nxengine.log"

printf "Starting Cave Story (Pickles)\n" >"$LOGPATH"
DOUK_BIOS="$MUOS_STORE_DIR/bios/nxengine/Doukutsu.exe"

GREENLIGHT=0
if /opt/muos/script/launch/nxengine-provision.sh "$LOGPATH"; then
	GREENLIGHT=1
else
	printf "Cave Story data is unavailable\n" >>"$LOGPATH"
fi

if [ "$GREENLIGHT" -eq 1 ]; then
	printf "Launching Cave Story\n" >>"$LOGPATH"

	/opt/muos/frontend/muxretro "$MUOS_SHARE_DIR/core/nxengine_libretro.so" "$DOUK_BIOS" $FRESH_ARG
fi
