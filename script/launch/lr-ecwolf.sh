#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)
IS_SWAP=$(DETECT_CONTROL_SWAP)

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/ecwolf.log"
mkdir -p "$(dirname "$LOGPATH")"
printf "Starting Wolfenstein 3D\n" >"$LOGPATH"

SHOW_MESSAGE 50 "Loading Wolfenstein Content"

if ! WOLF_EXE=$(/opt/muos/script/launch/wolf-provision.sh "$(dirname "$FILE")" "$NAME" "$LOGPATH" 2>&1); then
	SHOW_MESSAGE 100 "Error Loading Wolfenstein Content\n\n$WOLF_EXE"

	MESSAGE stop
	sleep 3

	exit 1
fi

MESSAGE stop

set -- -v -f
[ -n "$RA_ARGS" ] && set -- "$@" "$RA_ARGS"
retroarch "$@" -L "$MUOS_SHARE_DIR/core/ecwolf_libretro.so" "$WOLF_EXE"

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
