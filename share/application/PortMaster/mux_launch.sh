#!/bin/sh
# HELP: PortMaster
# ICON: portmaster
# GRID: PortMaster

. /opt/muos/script/var/func.sh

APP_BIN="portmaster"
SETUP_APP "$APP_BIN" ""

# -----------------------------------------------------------------------------

PORTMASTER_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
cd "$PORTMASTER_DIR" || exit

export SDL_RENDER_VSYNC=1
export SDL_HINT_VIDEO_DOUBLE_BUFFER=1

bash ./PortMaster.sh
