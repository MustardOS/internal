#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask

MUOS_HIST_DIR="$DC_STO_ROM_MOUNT/MUOS/info/history"

echo "Deleting History Files"
rm -rf "${MUOS_HIST_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
