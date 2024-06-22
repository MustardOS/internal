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

echo "Killing running web services"> /tmp/muxlog_info
killall sshd
killall sftpgo
killall gotty
killall syncthing

echo "Bringing Network Interface Down" > /tmp/muxlog_info
if [ $NET_INTERFACE = "wlan0" ]; then
	killall wpa_supplicant
fi
killall dhcpcd
ip link set "$NET_INTERFACE" down

echo "Removing WPA Supplicant" > /tmp/muxlog_info
rm -rf "/etc/wpa_supplicant.conf"

echo "Reverting to original network settings" > /tmp/muxlog_info
modify_ini "$CONFIG" "network" "enabled" "0"
modify_ini "$CONFIG" "network" "type" "0"
modify_ini "$CONFIG" "network" "ssid" ""
modify_ini "$CONFIG" "network" "address" "192.168.0.123"
modify_ini "$CONFIG" "network" "subnet" "24"
modify_ini "$CONFIG" "network" "gateway" "192.168.0.1"
modify_ini "$CONFIG" "network" "dns" "1.1.1.1"

# Sync filesystem just-in-case :)
echo "Sync Filesystem" > /tmp/muxlog_info
sync

echo "All Done!" > /tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

# Resume the muxtask program
pkill -CONT muxtask
killall -q "Restore Network Configuration.sh"
