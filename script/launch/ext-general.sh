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

# Stage overlay currently disabled for all external content launch
# until such time what is causing certain titles to become black
# screen.  Most likely conflicts with the overlay rendering.

# SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

IS_32BIT=0
grep -q '^[[:space:]]*[^#]*PORT_32BIT="Y"' "$FILE" && IS_32BIT=1

if [ $IS_32BIT -eq 1 ]; then
	export PIPEWIRE_MODULE_DIR="/usr/lib32/pipewire-0.3"
	export SPA_PLUGIN_DIR="/usr/lib32/spa-0.2"
fi

"$FILE"

[ $IS_32BIT -eq 1 ] && unset PIPEWIRE_MODULE_DIR SPA_PLUGIN_DIR
