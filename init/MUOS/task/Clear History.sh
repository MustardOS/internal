#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/global/storage.sh

pkill -STOP muxtask

MUOS_HIST_DIR="$GC_STO_FAV/MUOS/info/history"

echo "Deleting History Files"
rm -rf "${MUOS_HIST_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
