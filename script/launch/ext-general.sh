#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

if [ "$CORE" != "external" ]; then
	SETUP_STAGE_OVERLAY
fi

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "external"

IS_32BIT=0
grep -q '^[[:space:]]*[^#]*PORT_32BIT="Y"' "$FILE" && IS_32BIT=1

if [ "$IS_32BIT" -eq 1 ]; then
	export PIPEWIRE_MODULE_DIR="/usr/lib32/pipewire-0.3"
	export SPA_PLUGIN_DIR="/usr/lib32/spa-0.2"
fi

"$FILE"

[ "$IS_32BIT" -eq 1 ] && unset PIPEWIRE_MODULE_DIR SPA_PLUGIN_DIR
