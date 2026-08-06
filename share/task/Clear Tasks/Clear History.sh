#!/bin/sh
# HELP: Clear History
# ICON: clear
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "clear_history" "Clear History"


MUOS_HIST_DIR="$MUOS_STORE_DIR/info/history"

TASK_STATUS "Deleting History Files"
rm -rf "${MUOS_HIST_DIR:?}"/*

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Clear History"

exit 0
