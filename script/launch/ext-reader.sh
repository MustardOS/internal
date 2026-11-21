#!/bin/sh

. /opt/muos/script/var/display.sh
. /opt/muos/script/var/launch.sh

SETUP_SDL_ENVIRONMENT
SET_VAR "system" "foreground_process" "muxreader"

/opt/muos/frontend/module/muxreader "$FILE"
