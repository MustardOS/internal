#!/bin/sh
# HELP: Run Dot and Junk File Cleanup
# ICON: junk

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

DELETE_CRUFT() {
	CRUFT="._* .DS_Store desktop.ini Thumbs.db .Trashes .Spotlight .fseventsd .DStore"

	for C in $CRUFT; do
		echo "Removing all '$C' files"
		find "$1" -type f -name "$C" -exec rm -f {} +
	done
}

echo "Checking ROM for junk"
DELETE_CRUFT "$(GET_VAR "device" "storage/rom/mount")"

echo "Checking SDCARD for junk"
DELETE_CRUFT "$(GET_VAR "device" "storage/sdcard/mount")"

echo "Checking USB for junk"
DELETE_CRUFT "$(GET_VAR "device" "storage/usb/mount")"

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
