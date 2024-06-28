#!/bin/sh

# USB Ethernet script created for muOS 2405.1 Refried Beans +
# This script will toggle the iface between eth0 and wlan0
# Additionally it'll enable network and PortMaster, and generate SSH Keys if needed.

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/network.sh

pkill -STOP muxtask
/opt/muos/extra/muxlog &
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

MODIFY_INI "$DEVICE_CONFIG" "device" "network" "1"
MODIFY_INI "$DEVICE_CONFIG" "device" "portmaster" "1"
if [ "$DC_NET_INTERFACE" = "wlan0" ]; then
	echo "Switching to 'eth0'" >/tmp/muxlog_info
	MODIFY_INI "$DEVICE_CONFIG" "network" "iface" "eth0"
else
	echo "Switching to 'wlan0'" >/tmp/muxlog_info
	MODIFY_INI "$DEVICE_CONFIG" "network" "iface" "wlan0"
fi

/opt/openssh/bin/ssh-keygen -A

echo "All Done!" >/tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

pkill -CONT muxtask
killall -q "Toggle Ethernet.sh"
