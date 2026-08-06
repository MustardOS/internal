#!/bin/sh
# HELP: Clear Network Profiles
# ICON: clear
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "clear_network_profiles" "Clear Network Profiles"


MUOS_NP_DIR="$MUOS_STORE_DIR/network"

TASK_STATUS "Deleting Network Profiles"
rm -rf "${MUOS_NP_DIR:?}"/*

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Clear Network Profiles"

exit 0
