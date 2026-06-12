#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

MPV_BIN="mpv"
SET_VAR "system" "foreground_process" "$MPV_BIN"

GPTOKEYB "$MPV_BIN" "$CORE"

set -- --no-config --fullscreen --keepaspect=yes --video-zoom=0 --video-align-x=0 --video-align-y=0

case "$CORE" in
	ext-mpv-general) $MPV_BIN "$@" "$FILE" ;;
	ext-mpv-livetv) $MPV_BIN "$@" "$(cat "$FILE")" ;;
	ext-mpv-radio) $MPV_BIN --no-video "$(cat "$FILE")" ;;
esac
