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

# storage.sh reports why it failed, so all that is left to say here is how it ended
if /opt/muos/script/device/storage.sh "sdcard" "mount"; then
	TASK_STATUS "Sync Filesystem"
	sync

	TASK_COMPLETE "Secondary Storage mounted"
	exit 0
fi

TASK_COMPLETE "Secondary Storage could not be mounted"
exit 1
