#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
if [ -d "$STORE_ROM/ROMS" ]; then
	ROMPATH="/$STORE_ROM/ROMS"
fi

STORE_SDCARD=$(parse_ini "$DEVICE_CONFIG" "storage.sdcard" "mount")
if [ -d "$STORE_SDCARD/ROMS" ]; then
	ROMPATH="${ROMPATH} /$STORE_SDCARD/ROMS"
fi

STORE_USB=$(parse_ini "$DEVICE_CONFIG" "storage.usb" "mount")
if [ -d "$STORE_USB/ROMS" ]; then
	ROMPATH="${ROMPATH} /$STORE_USB/ROMS"
fi

/opt/muos/bin/rg --files "${ROMPATH}" 2>&1 | /opt/muos/bin/rg --pcre2 -i "\/(?!.*\/).*$1"

