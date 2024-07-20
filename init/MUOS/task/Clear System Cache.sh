#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask

MUOS_CACHE_DIR="$DC_STO_ROM_MOUNT/MUOS/info/cache"

echo "Clearing all cache"
rm -rf "$MUOS_CACHE_DIR"/mmc/* "$MUOS_CACHE_DIR"/sdcard/* "$MUOS_CACHE_DIR"/usb/*

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
