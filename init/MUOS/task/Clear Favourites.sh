#!/bin/sh
# HELP: Clear Favourites
# ICON: clear

. /opt/muos/script/var/func.sh

pkill -STOP muxfrontend

MUOS_FAV_DIR="/run/muos/storage/info/favourite"

echo "Deleting Favourite Files"
rm -rf "${MUOS_FAV_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

pkill -CONT muxfrontend
exit 0
