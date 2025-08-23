#!/bin/sh
# HELP: Enable Wi-Fi using an 8188eu chipset USB adapter
# ICON: ethernet

# USB Wi-Fi script created for muOS 2508.0 Goose +
# This script will set wlan0 to use the 8188eu driver
# Additionally it'll enable network and PortMaster, and generate SSH Keys if needed.

. /opt/muos/script/var/func.sh

FRONTEND stop

SET_VAR "device" "board/network" "1"
SET_VAR "device" "board/portmaster" "1"

SET_VAR "device" "network/module" /lib/modules/4.9.170/kernel/drivers/net/wireless/rtl8188eu/8188eu.ko
SET_VAR "device" "network/name" "8188eu"

/opt/openssh/bin/ssh-keygen -A

echo "Sync Filesystem"
sync

echo "All Done!"
echo "Please restart your device."
TBOX sleep 2

FRONTEND start task
exit 0
