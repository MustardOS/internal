#!/bin/sh
# HELP: Will attempt to mount any secondary storage that has been configured by the system
# ICON: storage
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "mount_secondary_storage" "Mount Secondary Storage"


TASK_STATUS "Trying to mount Secondary Storage"
/opt/muos/script/device/storage.sh "sdcard" "mount"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Mount Secondary Storage"

exit 0
