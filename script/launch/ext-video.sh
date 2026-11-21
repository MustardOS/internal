#!/bin/sh

. /opt/muos/script/var/display.sh
. /opt/muos/script/var/launch.sh

SETUP_SDL_ENVIRONMENT
SET_VAR "system" "foreground_process" "muxmedia"

if [ -f /tmp/muos/wasabi_history_launch ]; then
	rm -f /tmp/muos/wasabi_history_launch
	/opt/muos/frontend/module/muxmedia --history "$FILE"
else
	/opt/muos/frontend/module/muxmedia "$FILE"
fi
