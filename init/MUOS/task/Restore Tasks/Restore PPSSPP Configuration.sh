#!/bin/sh
# HELP: Restore the default PPSSPP-SA settings and hotkeys.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

MOUNT="$(GET_VAR "device" "storage/rom/mount")"

echo "Restoring PPSSPP Configuration"
DEVICE_PREFIX="rg tui"
for PREFIX in $DEVICE_PREFIX; do
    rm -f "$MOUNT/MUOS/emulator/ppsspp/${PREFIX}/.config/ppsspp/PSP/SYSTEM/controls.ini"
    rm -f "$MOUNT/MUOS/emulator/ppsspp/${PREFIX}/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
done
/opt/muos/device/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

FRONTEND start task
exit 0
