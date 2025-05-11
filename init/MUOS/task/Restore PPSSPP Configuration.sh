#!/bin/sh
# HELP: Restore the default PPSSPP-SA settings and hotkeys.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

MOUNT="$(GET_VAR device storage/rom/mount)"

echo "Restoring PPSSPP Configuration"
rm -f "$MOUNT/MUOS/emulator/ppsspp/rg/.config/ppsspp/PSP/SYSTEM/controls.ini" \
	  "$MOUNT/MUOS/emulator/ppsspp/rg/.config/ppsspp/PSP/SYSTEM/ppsspp.ini" \
	  "$MOUNT/MUOS/emulator/ppsspp/tui/.config/ppsspp/PSP/SYSTEM/controls.ini" \
	  "$MOUNT/MUOS/emulator/ppsspp/tui/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
/opt/muos/device/current/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

FRONTEND start task
exit 0
