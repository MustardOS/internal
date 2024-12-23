#!/bin/sh
# HELP: Restore Network Configuration
# ICON: network

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

echo "Reverting to original network settings"
SET_VAR "global" "network/enabled" "0"
SET_VAR "global" "network/type" "0"
SET_VAR "global" "network/ssid" ""
SET_VAR "global" "network/pass" ""
SET_VAR "global" "network/address" "192.168.0.123"
SET_VAR "global" "network/subnet" "24"
SET_VAR "global" "network/gateway" "192.168.0.1"
SET_VAR "global" "network/dns" "1.1.1.1"

echo "Removing WPA Supplicant"
rm -rf "/etc/wpa_supplicant.conf"

echo "Bringing Network Interface Down"
/opt/muos/script/system/network.sh

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
