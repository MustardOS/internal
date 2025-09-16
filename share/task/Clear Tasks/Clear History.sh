#!/bin/sh
# HELP: Clear History
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_HIST_DIR="$MUOS_STORE_DIR/info/history"

echo "Deleting History Files"
rm -rf "${MUOS_HIST_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
