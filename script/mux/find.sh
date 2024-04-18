#!/bin/bash

ROMPATH=/mnt/mmc/ROMS

if [ -d /mnt/sdcard/ROMS ]; then
	ROMPATH="${ROMPATH} /mnt/sdcard/ROMS"
fi

if [ -d /mnt/usb/ROMS ]; then
	ROMPATH="${ROMPATH} /mnt/usb/ROMS"
fi

/opt/muos/bin/rg --files ${ROMPATH} 2>&1 | /opt/muos/bin/rg --pcre2 -i "\/(?!.*\/).*$1"

