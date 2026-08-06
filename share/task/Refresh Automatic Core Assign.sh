#!/bin/sh
# HELP: Refresh Automatic Core Assign
# ICON: junk
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "refresh_automatic_core_assign" "Refresh Automatic Core Assign"


/opt/muos/script/system/assign.sh -p -v

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Refresh Automatic Core Assign"
sleep 5

exit 0
