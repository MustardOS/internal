#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)
IS_SWAP=$(DETECT_CONTROL_SWAP)

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/prboom.log"
mkdir -p "$(dirname "$LOGPATH")"
printf "Starting DOOM\n" >"$LOGPATH"

SHOW_MESSAGE 50 "Loading DOOM Content"

if ! PRBW=$(/opt/muos/script/launch/doom-provision.sh "$(dirname "$FILE")" "$NAME" "$LOGPATH" 2>&1); then
	SHOW_MESSAGE 100 "Error Loading DOOM Content\n\n$PRBW"

	MESSAGE stop
	sleep 3

	exit 1
fi

MESSAGE stop

set -- -v -f
[ -n "$RA_ARGS" ] && set -- "$@" "$RA_ARGS"
retroarch "$@" -L "$MUOS_SHARE_DIR/core/prboom_libretro.so" "$PRBW"

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
