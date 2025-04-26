#!/bin/sh
# HELP: Clear History
# ICON: clear

. /opt/muos/script/var/func.sh

pkill -STOP muxfrontend

MUOS_HIST_DIR="/run/muos/storage/info/history"

echo "Deleting History Files"
rm -rf "${MUOS_HIST_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

pkill -CONT muxfrontend
exit 0
