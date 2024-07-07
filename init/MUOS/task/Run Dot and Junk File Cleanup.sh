#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

DELETE_CRUFT() {
	CRUFT="._* .DS_Store desktop.ini Thumbs.db .Trashes .Spotlight .fseventsd .DStore"

	for C in $CRUFT; do
		find "$1" -type f -name "$C" -exec rm -f {} +
	done
}

DELETE_CRUFT "$DC_STO_ROM_MOUNT"
DELETE_CRUFT "$DC_STO_SDCARD_MOUNT"
DELETE_CRUFT "$DC_STO_USB_MOUNT"
