#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask
/opt/muos/extra/muxlog &
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

MUOS_CACHE_DIR="$DC_STO_ROM_MOUNT/MUOS/info/cache"

echo "Clearing all cache" >/tmp/muxlog_info
rm -rf "$MUOS_CACHE_DIR"/mmc/* "$MUOS_CACHE_DIR"/sdcard/* "$MUOS_CACHE_DIR"/usb/*

echo "Sync Filesystem" >/tmp/muxlog_info
sync

echo "All Done!" >/tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

pkill -CONT muxtask
killall -q "Clear System Cache.sh"
