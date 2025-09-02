#!/bin/sh
# HELP: Toggle Syncthing Auto-Scan
# ICON: network

# This script toggles if API calls to Syncthing after content close
# and shutdown are enabled or not.

. /opt/muos/script/var/func.sh

FRONTEND stop

if [ "$(GET_VAR "config" "syncthing/auto_scan")" -eq 0 ]; then
	echo "Turning on Syncthing Auto-Scan"
	SET_VAR "config" "syncthing/auto_scan" "1"
else
	echo "Turning off Syncthing Auto-Scan"
	SET_VAR "config" "syncthing/auto_scan" "0"
fi

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
