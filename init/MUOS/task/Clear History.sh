#!/bin/sh
# HELP: Clear History
# ICON: clear

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

MUOS_HIST_DIR="/run/muos/storage/info/history"

echo "Deleting History Files"
rm -rf "${MUOS_HIST_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
