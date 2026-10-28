#!/bin/sh
# HELP: Removes hidden files and folders left behind by other computers, such as .DS_Store, ._ files, Thumbs.db, desktop.ini and System Volume Information, from SD1, SD2 and USB storage. Your content and saves are not touched.
# ICON: junk
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/boot.sh
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
