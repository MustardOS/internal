#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask

DELETE_CRUFT() {
	CRUFT="._* .DS_Store desktop.ini Thumbs.db .Trashes .Spotlight .fseventsd .DStore"

	for C in $CRUFT; do
		echo "Removing all '$C' files"
		find "$1" -type f -name "$C" -exec rm -f {} +
	done
}

echo "Cleaning up junk files"
DELETE_CRUFT "$DC_STO_ROM_MOUNT"
DELETE_CRUFT "$DC_STO_SDCARD_MOUNT"
DELETE_CRUFT "$DC_STO_USB_MOUNT"

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
