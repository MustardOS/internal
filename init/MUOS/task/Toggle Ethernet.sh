#!/bin/sh

# USB Ethernet script created for muOS 2405.1 Refried Beans +
# This script will toggle the iface between eth0 and wlan0
# Additionally it'll enable network and PortMaster, and generate SSH Keys if needed.

# Suspend the muxtask program
pkill -STOP muxtask

# Fire up the logger!
/opt/muos/extra/muxlog &
sleep 1

echo "Waiting..." > /tmp/muxlog_info
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

DEV_IFACE=$(parse_ini "$DEVICE_CONFIG" "network" "iface")

modify_ini "$DEVICE_CONFIG" "device" "network" "1"
modify_ini "$DEVICE_CONFIG" "device" "portmaster" "1"
if [ $DEV_IFACE = "wlan0" ]; then
    echo "Enabling eth0" > /tmp/muxlog_info
    modify_ini "$DEVICE_CONFIG" "network" "iface" "eth0"
else
    echo "Disabling eth0" > /tmp/muxlog_info
    modify_ini "$DEVICE_CONFIG" "network" "iface" "wlan0"
fi

# Generate SSH Keys
/opt/openssh/bin/ssh-keygen -A

echo "All Done!" > /tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

# Resume the muxtask program
pkill -CONT muxtask
killall -q "Backup Wifi.sh"
