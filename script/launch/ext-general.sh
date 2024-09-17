#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=$(GET_VAR "device" "board/home")

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

IS_32BIT=0
if grep -q 'PORT_32BIT="Y"' "$ROM"; then
	IS_32BIT=1
fi

if [ $IS_32BIT -eq 1 ]; then
	killall -q "golden.sh" "pw-play"
	export PIPEWIRE_MODULE_DIR="/usr/lib32/pipewire-0.3"
    export SPA_PLUGIN_DIR="/usr/lib32/spa-0.2"
fi

"$ROM"

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
unset PIPEWIRE_MODULE_DIR
unset SPA_PLUGIN_DIR

/opt/muos/script/mux/golden.sh &
