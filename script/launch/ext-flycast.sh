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

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

SET_VAR "system" "foreground_process" "flycast"

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/flycast"

chmod +x "$EMUDIR"/flycast
cd "$EMUDIR" || exit

HOME="$EMUDIR" SDL_ASSERT=always_ignore FLYCAST_BIOS_PATH=/run/muos/storage/bios/dc/ ./flycast "$FILE"

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
