#!/bin/sh
# HELP: Toggle Ethernet
# ICON: ethernet

# USB Ethernet script created for muOS 2405.1 Refried Beans +
# This script will toggle the iface between eth0 and wlan0
# Additionally it'll enable network and PortMaster, and generate SSH Keys if needed.

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

SET_VAR "device" "board/network" "1"
SET_VAR "device" "board/portmaster" "1"

if [ "$(GET_VAR "device" "network/iface")" = "wlan0" ]; then
	echo "Switching to 'eth0'"
	SET_VAR "device" "network/iface" "eth0"
else
	echo "Switching to 'wlan0'"
	SET_VAR "device" "network/iface" "wlan0"
fi

/opt/openssh/bin/ssh-keygen -A

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
