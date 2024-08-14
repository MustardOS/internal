#!/bin/sh

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

MUOS_FAV_DIR="$(GET_VAR "global" "storage/fav")/MUOS/info/favourite"

echo "Deleting Favourite Files"
rm -rf "${MUOS_FAV_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
