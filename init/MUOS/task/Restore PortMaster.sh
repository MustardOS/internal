#!/bin/sh

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

MUOS_NEW_PM_DIR="/opt/muos/archive/portmaster"
MUOS_PM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"

echo "Deleting existing PortMaster install"
rm -rf "${MUOS_PM_DIR:?}"/*

echo "Reinstalling PortMaster from base"
cp -r "$MUOS_NEW_PM_DIR"/* "$MUOS_PM_DIR"/.

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
