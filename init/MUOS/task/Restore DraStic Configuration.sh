#!/bin/sh
# HELP: Restore the default DraStic settings and hotkeys.
# ICON: retroarch

. /opt/muos/script/var/func.sh

pkill -STOP muxfrontend

MOUNT="$(GET_VAR device storage/rom/mount)"

echo "Restoring DraStic Configuration"
rm -f "$MOUNT/MUOS/emulator/drastic-trngaje/config/drastic.cfg" \
	"$MOUNT/MUOS/emulator/drastic-trngaje/resources/settings.json"
/opt/muos/device/current/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

pkill -CONT muxfrontend
exit 0
