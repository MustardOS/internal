#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "muxretro"

FRESH_ARG=""
[ -e "/tmp/ra_no_load" ] && FRESH_ARG="--fresh"

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/ecwolf.log"
mkdir -p "$(dirname "$LOGPATH")"
printf "Starting Wolfenstein 3D (Pickles)\n" >"$LOGPATH"

SHOW_MESSAGE 50 "Loading Wolfenstein Content"

if ! WOLF_EXE=$(/opt/muos/script/launch/wolf-provision.sh "$(dirname "$FILE")" "$NAME" "$LOGPATH" 2>&1); then
	SHOW_MESSAGE 100 "Error Loading Wolfenstein Content\n\n$WOLF_EXE"

	MESSAGE stop
	sleep 3

	exit 1
fi

MESSAGE stop

/opt/muos/frontend/muxretro "$MUOS_SHARE_DIR/core/ecwolf_libretro.so" "$WOLF_EXE" $FRESH_ARG
