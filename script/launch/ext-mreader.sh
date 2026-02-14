#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

READER_DIR="$MUOS_SHARE_DIR/emulator/mreader"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

READER_BIN="reader"
SET_VAR "system" "foreground_process" "$READER_BIN"

cd "$READER_DIR" || exit

if [ "$CORE" = "ext-mreader-landscape" ]; then
	SCREEN_WIDTH="$(GET_VAR "device" "mux/width")"
	SCREEN_HEIGHT="$(GET_VAR "device" "mux/height")"
	SDL_ROTATION=0
elif [ "$CORE" = "ext-mreader-portrait" ]; then
	SCREEN_WIDTH="$(GET_VAR "device" "mux/height")"
	SCREEN_HEIGHT="$(GET_VAR "device" "mux/width")"
	SDL_ROTATION=1
fi

export SCREEN_WIDTH SCREEN_HEIGHT SDL_ROTATION

GPTOKEYB "$READER_BIN" "$CORE"
LD_LIBRARY_PATH="$READER_DIR/libs:$LD_LIBRARY_PATH" ./$READER_BIN "$FILE"
