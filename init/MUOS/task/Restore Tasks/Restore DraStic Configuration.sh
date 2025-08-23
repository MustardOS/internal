#!/bin/sh
# HELP: Restore the default DraStic settings and hotkeys.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

MOUNT="$(GET_VAR "device" "storage/rom/mount")"

echo "Restoring DraStic Configuration"
rm -f "$MOUNT/MUOS/emulator/drastic-trngaje/config/drastic.cfg" \
	"$MOUNT/MUOS/emulator/drastic-trngaje/resources/settings.json"
/opt/muos/device/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
