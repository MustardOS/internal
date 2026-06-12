#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

READER_DIR="$MUOS_SHARE_DIR/emulator/mreader"

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

READER_BIN="reader"
SET_VAR "system" "foreground_process" "$READER_BIN"

cd "$READER_DIR" || exit

case "$CORE" in
	ext-mreader-landscape)
		SCREEN_WIDTH="$(GET_VAR "device" "mux/width")"
		SCREEN_HEIGHT="$(GET_VAR "device" "mux/height")"
		SDL_ROTATION=0
		;;
	ext-mreader-portrait)
		SCREEN_WIDTH="$(GET_VAR "device" "mux/height")"
		SCREEN_HEIGHT="$(GET_VAR "device" "mux/width")"
		SDL_ROTATION=1
		;;
esac

export SCREEN_WIDTH SCREEN_HEIGHT SDL_ROTATION

GPTOKEYB "$READER_BIN" "$CORE"
LD_LIBRARY_PATH="$READER_DIR/libs:$LD_LIBRARY_PATH" ./$READER_BIN "$FILE"
