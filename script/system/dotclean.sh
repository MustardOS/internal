#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

CRUFT="._* .DS_Store desktop.ini Thumbs.db .Trashes .Spotlight .fseventsd .DStore"

DELETE_CRUFT() {
    for C in $CRUFT; do
        find "$1" -type f -name "$C" -exec rm -f {} +
    done
}

DELETE_CRUFT "$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")"
DELETE_CRUFT "$(parse_ini "$DEVICE_CONFIG" "storage.sdcard" "mount")"
DELETE_CRUFT "$(parse_ini "$DEVICE_CONFIG" "storage.usb" "mount")"

