#!/bin/sh
# HELP: Restore the default YabaSanshiro Controls.
# ICON: retroarch

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

MOUNT="$(GET_VAR device storage/rom/mount)"

echo "Restoring YabaSanshiro Configuration"
rm -f "$MOUNT/MUOS/emulator/yabasanshiro/.emulationstation/es_temporaryinput.cfg" \
	"$MOUNT/MUOS/emulator/yabasanshiro/.yabasanshiro/keymapv2.json"
/opt/muos/device/current/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
