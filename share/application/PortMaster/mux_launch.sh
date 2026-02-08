#!/bin/sh
# HELP: PortMaster
# ICON: portmaster
# GRID: PortMaster

STAGE_OVERLAY=0 . /opt/muos/script/var/func.sh

APP_BIN="portmaster"
SETUP_APP "$APP_BIN" ""

# -----------------------------------------------------------------------------

PORTMASTER_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
cd "$PORTMASTER_DIR" || exit

./PortMaster.sh
