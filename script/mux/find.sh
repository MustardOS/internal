#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

if [ -d "$DC_STO_ROM_MOUNT/ROMS" ]; then
	ROMPATH="$DC_STO_ROM_MOUNT/ROMS"
fi

if [ -d "$DC_STO_SDCARD_MOUNT/ROMS" ]; then
	ROMPATH="${ROMPATH} /$DC_STO_SDCARD_MOUNT/ROMS"
fi

if [ -d "$DC_STO_USB_MOUNT/ROMS" ]; then
	ROMPATH="${ROMPATH} /$DC_STO_USB_MOUNT/ROMS"
fi

/opt/muos/bin/rg --files "${ROMPATH}" 2>&1 | /opt/muos/bin/rg --pcre2 -i "\/(?!.*\/).*$1"
