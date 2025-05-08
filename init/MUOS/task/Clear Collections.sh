#!/bin/sh
# HELP: Clear Collections
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_COLL_DIR="/run/muos/storage/info/collection"

echo "Deleting Collection Files"
rm -rf "${MUOS_COLL_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

FRONTEND start task
exit 0
