#!/bin/sh

# Grab device variables
. /opt/muos/script/system/parse.sh
DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

ROM_MOUNT=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

# Suspend the muxtask program
pkill -STOP muxtask

# Fire up the logger!
/opt/muos/extra/muxlog &
sleep 1

echo "Waiting..." > /tmp/muxlog_info
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

# Grab current date
DATE=$(date +%Y-%m-%d)

# muOS Favourites Directory
MUOS_CACHE_DIR="$ROM_MOUNT/MUOS/info/cache"

echo "Clearing all cache" > /tmp/muxlog_info
rm -rf "$MUOS_CACHE_DIR"/mmc/*
rm -rf "$MUOS_CACHE_DIR"/sdcard/*
rm -rf "$MUOS_CACHE_DIR"/usb/*

# Sync filesystem just-in-case :)
echo "Sync Filesystem" > /tmp/muxlog_info
sync

echo "All Done!" > /tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

# Resume the muxtask program
pkill -CONT muxtask
killall -q "Clear System Cache.sh"
