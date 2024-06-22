#!/bin/sh

# Grab device variables
. /opt/muos/script/system/parse.sh

CONFIG=/opt/muos/config/config.ini

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

echo "Restoring RetroArch Configuration" > /tmp/muxlog_info
rm -rf "$ROM_MOUNT/MUOS/retroarch/retroarch.cfg"
/opt/muos/device/"$DEVICE"/script/control.sh

# Sync filesystem just-in-case :)
echo "Sync Filesystem" > /tmp/muxlog_info
sync

echo "All Done!" > /tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

# Resume the muxtask program
pkill -CONT muxtask
killall -q "Restore RetroArch Configuration.sh"
