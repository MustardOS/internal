#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask

MUOS_NEW_PM_DIR="/opt/muos/archive/portmaster"
MUOS_PM_DIR="$DC_STO_ROM_MOUNT/MUOS/PortMaster"

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
