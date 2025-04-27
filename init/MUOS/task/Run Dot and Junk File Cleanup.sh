#!/bin/sh
# HELP: Run Dot and Junk File Cleanup
# ICON: junk

. /opt/muos/script/var/func.sh

FRONTEND stop

DELETE_CRUFT() {
	find "$1" -type f \( \
		-name "._*" -o \
		-name ".DS_Store" -o \
		-name "desktop.ini" -o \
		-name "Thumbs.db" \
		-name ".DStore" \
		\) -exec rm -f {} +

	find "$1" -type d \( \
		-name "System Volume Information" -o \
		-name ".Trashes" -o \
		-name ".Spotlight" -o \
		-name ".fseventsd" \
		\) -exec rm -rf {} +
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
/opt/muos/bin/toybox sleep 2

FRONTEND start task
exit 0
