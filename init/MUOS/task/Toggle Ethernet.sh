#!/bin/sh

# USB Ethernet script created for muOS 2405.1 Refried Beans +
# This script will toggle the iface between eth0 and wlan0
# Additionally it'll enable network and PortMaster, and generate SSH Keys if needed.

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/network.sh

pkill -STOP muxtask

MODIFY_INI "$DEVICE_CONFIG" "device" "network" "1"
MODIFY_INI "$DEVICE_CONFIG" "device" "portmaster" "1"
if [ "$DC_NET_INTERFACE" = "wlan0" ]; then
	echo "Switching to 'eth0'"
	MODIFY_INI "$DEVICE_CONFIG" "network" "iface" "eth0"
else
	echo "Switching to 'wlan0'"
	MODIFY_INI "$DEVICE_CONFIG" "network" "iface" "wlan0"
fi

/opt/openssh/bin/ssh-keygen -A

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
