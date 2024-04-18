#!/bin/sh

CRUFT="._* .DS_Store desktop.ini Thumbs.db .Trashes .Spotlight .fseventsd .DStore"

DELETE_CRUFT() {
    for C in $CRUFT; do
        find "$1" -type f -name "$C" -exec rm -f {} +
    done
}

DELETE_CRUFT "/mnt/mmc"

if grep -m 1 "mmcblk1p1" /proc/partitions > /dev/null; then
	DELETE_CRUFT "/mnt/sdcard"
fi

if grep -m 1 "sda1" /proc/partitions > /dev/null; then
	DELETE_CRUFT "/mnt/usb"
fi

