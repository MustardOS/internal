#!/bin/sh
# HELP: Run Dot and Junk File Cleanup
# ICON: junk
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "dot_and_junk_file_cleanup" "Dot and Junk File Cleanup"


TASK_STATUS "Checking ROM for junk"
DELETE_CRUFT "$(GET_VAR "device" "storage/rom/mount")"

TASK_STATUS "Checking SDCARD for junk"
DELETE_CRUFT "$(GET_VAR "device" "storage/sdcard/mount")"

TASK_STATUS "Checking USB for junk"
DELETE_CRUFT "$(GET_VAR "device" "storage/usb/mount")"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Junk files removed"

exit 0
