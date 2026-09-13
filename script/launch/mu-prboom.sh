#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "muxretro"

FRESH_ARG=""
[ -e "/tmp/ra_no_load" ] && FRESH_ARG="--fresh"

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/prboom.log"
mkdir -p "$(dirname "$LOGPATH")"
printf "Starting DOOM (Pickles)\n" >"$LOGPATH"

SHOW_MESSAGE 50 "Loading DOOM Content"

if ! PRBW=$(/opt/muos/script/launch/doom-provision.sh "$(dirname "$FILE")" "$NAME" "$LOGPATH" 2>&1); then
	SHOW_MESSAGE 100 "Error Loading DOOM Content\n\n$PRBW"

	MESSAGE stop
	sleep 3

	exit 1
fi

MESSAGE stop

/opt/muos/frontend/muxretro "$MUOS_SHARE_DIR/core/prboom_libretro.so" "$PRBW" $FRESH_ARG
