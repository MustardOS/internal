#!/bin/sh

. /opt/muos/script/var/func.sh

pkill -STOP muxtask
/opt/muos/extra/muxlog &
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

echo "Reverting to original network settings" >/tmp/muxlog_info
MODIFY_INI "$GLOBAL_CONFIG" "network" "enabled" "0"
MODIFY_INI "$GLOBAL_CONFIG" "network" "type" "0"
MODIFY_INI "$GLOBAL_CONFIG" "network" "ssid" ""
MODIFY_INI "$GLOBAL_CONFIG" "network" "address" "192.168.0.123"
MODIFY_INI "$GLOBAL_CONFIG" "network" "subnet" "24"
MODIFY_INI "$GLOBAL_CONFIG" "network" "gateway" "192.168.0.1"
MODIFY_INI "$GLOBAL_CONFIG" "network" "dns" "1.1.1.1"

echo "Removing WPA Supplicant" >/tmp/muxlog_info
rm -rf "/etc/wpa_supplicant.conf"

echo "Bringing Network Interface Down" >/tmp/muxlog_info
/opt/muos/script/system/network.sh

echo "Sync Filesystem" >/tmp/muxlog_info
sync

echo "All Done!" >/tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

pkill -CONT muxtask
killall -q "Restore Network Configuration.sh"
