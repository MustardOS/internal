#!/bin/sh
# HELP: Toggle Ethernet
# ICON: ethernet
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

# USB Ethernet script created for muOS 2405.1 Refried Beans +
# This script will toggle the iface between eth0 and wlan0
# Additionally it'll enable network and PortMaster, and generate SSH Keys if needed.

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "toggle_ethernet" "Toggle Ethernet"


SET_VAR "device" "board/network" "1"
SET_VAR "device" "board/portmaster" "1"

if [ "$(GET_VAR "device" "network/iface")" = "wlan0" ]; then
	TASK_STATUS "Switching to 'eth0'"
	SET_VAR "device" "network/iface" "eth0"
	SET_VAR "device" "network/state" "/sys/class/net/eth0/operstate"
else
	TASK_STATUS "Switching to 'wlan0'"
	SET_VAR "device" "network/iface" "wlan0"
	SET_VAR "device" "network/state" "/sys/class/net/wlan0/operstate"
fi

/opt/openssh/bin/ssh-keygen -A

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Toggle Ethernet"

exit 0
