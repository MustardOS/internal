#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

# The fbdev blitter synchronises scanout to the panel.  Disabling it exposes
# uneven application submission cadence as visible repeats/flicker.
SETUP_SDL_ENVIRONMENT skip_blitter

SET_VAR "system" "foreground_process" "muxretro"

FRESH_ARG=""
[ -e "/tmp/ra_no_load" ] && FRESH_ARG="--fresh"

/opt/muos/frontend/muxretro "$MUOS_SHARE_DIR/core/$CORE" "$FILE" $FRESH_ARG
