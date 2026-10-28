#!/bin/sh
# HELP: Safely unmounts USB storage so the drive can be removed without losing data.
# ICON: storage
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/ui.sh

TASK_BEGIN "eject_usb_external_storage" "Eject USB External Storage"

TASK_STATUS "Trying to eject USB External Storage"

# storage.sh reports why it failed, so all that is left to say here is how it ended
if /opt/muos/script/device/storage.sh "usb" "eject"; then
	TASK_STATUS "Sync Filesystem"
	sync

	TASK_COMPLETE "USB External Storage ejected"
	exit 0
fi

TASK_COMPLETE "USB External Storage could not be ejected"
exit 1
