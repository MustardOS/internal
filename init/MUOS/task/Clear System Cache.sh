#!/bin/sh
# HELP: Clear System Cache
# ICON: clear

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

MUOS_CACHE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/cache"

echo "Clearing all cache"
rm -rf "$MUOS_CACHE_DIR"/mmc/* "$MUOS_CACHE_DIR"/sdcard/* "$MUOS_CACHE_DIR"/usb/*

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
