#!/bin/sh
# HELP: Clear Collections
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_COLL_DIR="$MUOS_STORE_DIR/info/collection"

echo "Deleting Collection Files"
rm -rf "${MUOS_COLL_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
