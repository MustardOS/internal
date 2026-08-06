#!/bin/sh
# HELP: Will attempt to eject any secondary storage that has been configured by the system
# ICON: storage
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "eject_secondary_storage" "Eject Secondary Storage"


TASK_STATUS "Trying to eject Secondary Storage"
/opt/muos/script/device/storage.sh "sdcard" "eject"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Eject Secondary Storage"

exit 0
