#!/bin/sh

. /opt/muos/script/var/func.sh

if [ -d "$(GET_VAR "device" "storage/rom/mount")/ROMS" ]; then
	ROMPATH="$(GET_VAR "device" "storage/rom/mount")/ROMS"
fi

if [ -d "$(GET_VAR "device" "storage/sdcard/mount")/ROMS" ]; then
	ROMPATH="${ROMPATH} /$(GET_VAR "device" "storage/sdcard/mount")/ROMS"
fi

if [ -d "$(GET_VAR "device" "storage/usb/mount")/ROMS" ]; then
	ROMPATH="${ROMPATH} /$(GET_VAR "device" "storage/usb/mount")/ROMS"
fi

/opt/muos/bin/rg --files "${ROMPATH}" 2>&1 | /opt/muos/bin/rg --pcre2 -i "\/(?!.*\/).*$1"
