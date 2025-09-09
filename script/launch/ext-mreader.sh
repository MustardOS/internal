#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

(
	LOG_INFO "$0" 0 "Content Launch" "DETAIL"
	LOG_INFO "$0" 0 "NAME" "$NAME"
	LOG_INFO "$0" 0 "CORE" "$CORE"
	LOG_INFO "$0" 0 "FILE" "$FILE"
) &

GPTOKEYB="$MUOS_SHARE_DIR/emulator/gptokeyb/gptokeyb2"
MREADER_DIR="$MUOS_SHARE_DIR/emulator/mreader"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

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

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

$GPTOKEYB "reader" -c "$MREADER_DIR/$ORIENTATION.gptk" &
LD_LIBRARY_PATH="$MREADER_DIR/libs:$LD_LIBRARY_PATH" ./reader "$FILE"

killall -q gptokeyb2

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
