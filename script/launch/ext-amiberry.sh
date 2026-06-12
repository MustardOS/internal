#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "amiberry"

EMUDIR="$MUOS_SHARE_DIR/emulator/amiberry"

chmod +x "$EMUDIR"/amiberry
cd "$EMUDIR" || exit

HOME="$EMUDIR" ./amiberry "$FILE"
