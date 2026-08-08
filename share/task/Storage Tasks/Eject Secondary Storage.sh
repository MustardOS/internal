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

# storage.sh reports why it failed, so all that is left to say here is how it ended
if /opt/muos/script/device/storage.sh "sdcard" "eject"; then
	TASK_STATUS "Sync Filesystem"
	sync

	TASK_COMPLETE "Secondary Storage ejected"
	exit 0
fi

TASK_COMPLETE "Secondary Storage could not be ejected"
exit 1
