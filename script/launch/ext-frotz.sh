#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "muterm"

TERM_CFG_DIR="/opt/muos/share/info/config/Terminal"
mkdir -p "$TERM_CFG_DIR"

/opt/muos/frontend/muterm --gl -c "$TERM_CFG_DIR"/"$NAME".conf -- /opt/muos/bin/dfrotz "$FILE"
