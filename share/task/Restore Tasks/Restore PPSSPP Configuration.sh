#!/bin/sh
# HELP: Restore the default PPSSPP-SA settings and hotkeys.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

MOUNT="$(GET_VAR "device" "storage/rom/mount")"

echo "Restoring PPSSPP Configuration"

DEVICE_PREFIX="rg tui"
for PREFIX in $DEVICE_PREFIX; do
	PPSSPP_SYS="$MOUNT/MUOS/emulator/ppsspp/${PREFIX}/.config/ppsspp/PSP/SYSTEM"
	rm -f "${PPSSPP_SYS}/controls.ini" "${PPSSPP_SYS}/ppsspp.ini"
done

/opt/muos/script/control/ppsspp.sh

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
