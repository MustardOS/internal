#!/bin/sh
# HELP: Toggle Syncthing Auto-Scan
# ICON: network
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

# This script toggles if API calls to Syncthing after content close
# and shutdown are enabled or not.

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "toggle_syncthing_auto_scan" "Toggle Syncthing Auto-Scan"


if [ "$(GET_VAR "config" "syncthing/auto_scan")" -eq 0 ]; then
	TASK_STATUS "Turning on Syncthing Auto-Scan"
	SET_VAR "config" "syncthing/auto_scan" "1"
else
	TASK_STATUS "Turning off Syncthing Auto-Scan"
	SET_VAR "config" "syncthing/auto_scan" "0"
fi

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Toggle Syncthing Auto-Scan"

exit 0
