#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_SDL_ENVIRONMENT
SET_VAR "system" "foreground_process" "muxmedia"

if [ -f /tmp/muos/wasabi_history_launch ]; then
	rm -f /tmp/muos/wasabi_history_launch
	/opt/muos/frontend/muxmedia --history "$FILE"
else
	/opt/muos/frontend/muxmedia "$FILE"
fi
