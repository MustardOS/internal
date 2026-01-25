#!/bin/sh
# HELP: Restore Network Configuration
# ICON: network

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Reverting to original network settings"
SET_VAR "config" "network/type" "0"
SET_VAR "config" "network/ssid" ""
SET_VAR "config" "network/pass" ""
SET_VAR "config" "network/hidden" ""
SET_VAR "config" "network/address" ""
SET_VAR "config" "network/gateway" ""
SET_VAR "config" "network/subnet" ""
SET_VAR "config" "network/dns" "1.1.1.1"

echo "Removing WPA Supplicant"
rm -rf "/etc/wpa_supplicant.conf"

echo "Restarting Network Interface"
/opt/muos/script/system/network.sh connect &

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

FRONTEND start task
exit 0
