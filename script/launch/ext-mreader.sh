#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"
MREADER_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/mreader"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"

SET_VAR "system" "foreground_process" "reader"

cd "$MREADER_DIR" || exit

if [ "$CORE" = "ext-mreader-landscape" ]; then
	ORIENTATION="landscape"
	SCREEN_WIDTH="$(GET_VAR "device" "mux/width")"
	SCREEN_HEIGHT="$(GET_VAR "device" "mux/height")"
	export SCREEN_WIDTH
	export SCREEN_HEIGHT
	export SDL_ROTATION=0
elif [ "$CORE" = "ext-mreader-portrait" ]; then
	ORIENTATION="portrait"
	SCREEN_WIDTH="$(GET_VAR "device" "mux/height")"
	SCREEN_HEIGHT="$(GET_VAR "device" "mux/width")"
	export SCREEN_WIDTH
	export SCREEN_HEIGHT
	export SDL_ROTATION=1
fi

$GPTOKEYB "reader" -c "$MREADER_DIR/$ORIENTATION.gptk" &
LD_LIBRARY_PATH="$MREADER_DIR/libs:$LD_LIBRARY_PATH" ./reader "$FILE"

killall -q gptokeyb2

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
