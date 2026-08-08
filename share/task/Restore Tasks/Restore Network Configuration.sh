#!/bin/sh
# HELP: Restore Network Configuration
# ICON: network
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_network_configuration" "Restore Network Configuration"


TASK_STATUS "Stopping Network Interface"
/opt/muos/script/init/async/S02network.sh stop

TASK_STATUS "Reverting to original network settings"
SET_VAR "config" "network/type" "0"
SET_VAR "config" "network/ssid" ""
SET_VAR "config" "network/pass" ""
SET_VAR "config" "network/hidden" ""
SET_VAR "config" "network/address" ""
SET_VAR "config" "network/gateway" ""
SET_VAR "config" "network/subnet" ""
SET_VAR "config" "network/dns" "1.1.1.1"

TASK_STATUS "Removing WPA Supplicant"
rm -rf "/etc/wpa_supplicant.conf"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Network configuration restored"

exit 0
