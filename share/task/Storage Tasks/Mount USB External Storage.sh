#!/bin/sh
# HELP: Will attempt to mount any USB external storage that has been configured by the system
# ICON: storage
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "mount_usb_external_storage" "Mount USB External Storage"


TASK_STATUS "Trying to mount USB External Storage"
/opt/muos/script/device/storage.sh "usb" "mount"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Mount USB External Storage"

exit 0
