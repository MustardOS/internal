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

# PortMaster New Directory
MUOS_NEW_PM_DIR="/opt/muos/archive/portmaster"

# PortMaster Directory
MUOS_PM_DIR="$ROM_MOUNT/MUOS/PortMaster"

echo "Deleting existing PortMaster install" > /tmp/muxlog_info
rm -rf "$MUOS_PM_DIR/*"

echo "Reinstalling PortMaster from base" > /tmp/muxlog_info
cp -r "$MUOS_NEW_PM_DIR/*" "$MUOS_PM_DIR/."

# Sync filesystem just-in-case :)
echo "Sync Filesystem" > /tmp/muxlog_info
sync

echo "All Done!" > /tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

# Resume the muxtask program
pkill -CONT muxtask
killall -q "Restore PortMaster.sh"
