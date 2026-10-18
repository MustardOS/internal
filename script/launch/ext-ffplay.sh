#!/bin/sh

. /opt/muos/script/var/stage.sh
. /opt/muos/script/var/display.sh
. /opt/muos/script/var/runtime.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

FFPLAY_BIN="ffplay"
SET_VAR "system" "foreground_process" "$FFPLAY_BIN"

GPTOKEYB "$FFPLAY_BIN" "$CORE"
$FFPLAY_BIN "$FILE" -fs
