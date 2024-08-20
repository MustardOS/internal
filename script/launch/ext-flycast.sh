#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=$(GET_VAR "device" "board/home")

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

SET_VAR "system" "foreground_process" "flycast"

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/flycast"

chmod +x "$EMUDIR"/flycast
cd "$EMUDIR" || exit

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./flycast "$ROM"

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
