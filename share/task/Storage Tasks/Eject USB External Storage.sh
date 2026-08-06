#!/bin/sh
# HELP: Will attempt to eject any external USB storage that has been configured by the system
# ICON: storage
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "eject_usb_external_storage" "Eject USB External Storage"


TASK_STATUS "Trying to eject USB External Storage"
/opt/muos/script/device/storage.sh "usb" "eject"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Eject USB External Storage"

exit 0
