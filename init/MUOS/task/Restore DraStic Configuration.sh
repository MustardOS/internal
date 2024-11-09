#!/bin/sh
# HELP: Restore the default DraStic settings and hotkeys.
# ICON: retroarch

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

MOUNT="$(GET_VAR device storage/rom/mount)"

echo "Restoring DraStic Configuration"
rm -f "$MOUNT/MUOS/emulator/drastic-trngaje/config/drastic.cfg" \
	"$MOUNT/MUOS/emulator/drastic-trngaje/resources/settings.json"
/opt/muos/device/current/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
