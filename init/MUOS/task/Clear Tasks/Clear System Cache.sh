#!/bin/sh
# HELP: Clear System Cache
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_CACHE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/cache"

echo "Clearing all cache"
rm -rf "${MUOS_CACHE_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
