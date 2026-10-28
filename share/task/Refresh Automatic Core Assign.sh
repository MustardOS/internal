#!/bin/sh
# HELP: Rebuilds the list that matches your content folder names to their systems and default cores. Use this after adding new system folders or manifests, or if folders are being matched to the wrong system.
# ICON: junk
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/ui.sh

TASK_BEGIN "refresh_automatic_core_assign" "Refresh Automatic Core Assign"


/opt/muos/script/system/assign.sh -p -v

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Core assignments refreshed"
sleep 5

exit 0
