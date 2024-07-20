#!/bin/sh

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

echo "Reverting to original network settings"
MODIFY_INI "$GLOBAL_CONFIG" "network" "enabled" "0"
MODIFY_INI "$GLOBAL_CONFIG" "network" "type" "0"
MODIFY_INI "$GLOBAL_CONFIG" "network" "ssid" ""
MODIFY_INI "$GLOBAL_CONFIG" "network" "address" "192.168.0.123"
MODIFY_INI "$GLOBAL_CONFIG" "network" "subnet" "24"
MODIFY_INI "$GLOBAL_CONFIG" "network" "gateway" "192.168.0.1"
MODIFY_INI "$GLOBAL_CONFIG" "network" "dns" "1.1.1.1"

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
