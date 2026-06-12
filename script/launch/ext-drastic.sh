#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "drastic"

EMUDIR="$MUOS_SHARE_DIR/emulator/drastic-trngaje"

chmod +x "$EMUDIR"/launch.sh
cd "$EMUDIR" || exit

HOME="$EMUDIR" ./launch.sh "$FILE"
