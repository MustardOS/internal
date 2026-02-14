#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "drastic"

EMUDIR="$MUOS_SHARE_DIR/emulator/drastic-trngaje"

chmod +x "$EMUDIR"/launch.sh
cd "$EMUDIR" || exit

HOME="$EMUDIR" ./launch.sh "$FILE"
