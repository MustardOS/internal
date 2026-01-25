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

SETUP_SDL_ENVIRONMENT

MPV_BIN="mpv"
SET_VAR "system" "foreground_process" "$MPV_BIN"

GPTOKEYB "$MPV_BIN" "$CORE"

MPV_VIDEO_OPTS="--no-config --fullscreen --keepaspect=yes --video-zoom=0 --video-align-x=0 --video-align-y=0"

if [ "$CORE" = "ext-mpv-general" ]; then
	$MPV_BIN $MPV_VIDEO_OPTS "$FILE"
elif [ "$CORE" = "ext-mpv-livetv" ]; then
	$MPV_BIN $MPV_VIDEO_OPTS "$(cat "$FILE")"
elif [ "$CORE" = "ext-mpv-radio" ]; then
	$MPV_BIN --no-video "$(cat "$FILE")"
fi
