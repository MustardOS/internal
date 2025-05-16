#!/bin/sh
# HELP: Clear History
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_HIST_DIR="/run/muos/storage/info/history"

echo "Deleting History Files"
rm -rf "${MUOS_HIST_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

FRONTEND start task
exit 0
