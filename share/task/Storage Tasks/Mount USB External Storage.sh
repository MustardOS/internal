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

# storage.sh reports why it failed, so all that is left to say here is how it ended
if /opt/muos/script/device/storage.sh "usb" "mount"; then
	TASK_STATUS "Sync Filesystem"
	sync

	TASK_COMPLETE "USB External Storage mounted"
	exit 0
fi

TASK_COMPLETE "USB External Storage could not be mounted"
exit 1
