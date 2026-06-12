#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "flycast"

EMUDIR="$MUOS_SHARE_DIR/emulator/flycast"

chmod +x "$EMUDIR"/flycast
cd "$EMUDIR" || exit

HOME="$EMUDIR" FLYCAST_BIOS_PATH="$MUOS_STORE_DIR/bios/dc/" ./flycast "$FILE"
