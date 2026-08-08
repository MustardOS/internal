#!/bin/sh
# HELP: Refresh Bootlogo
# ICON: theme
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "refresh_bootlogo" "Refresh Bootlogo"

TASK_STATUS "Rebuilding Boot Logo"
UPDATE_BOOTLOGO

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Boot logo refreshed"

exit 0
