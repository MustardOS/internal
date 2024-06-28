#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/setting_advanced.sh

if [ "$1" = "?R" ] && [ "$GC_ADV_RANDOM_THEME" -eq 1 ]; then
	THEME=$(find "$DC_STO_ROM_MOUNT/MUOS/theme" -name '*.zip' | shuf -n 1)
else
	THEME="$DC_STO_ROM_MOUNT/MUOS/theme/$1.zip"
fi

THEME_DIR="$DC_STO_ROM_MOUNT/MUOS/theme"

BOOTLOGO_DEF="/opt/muos/device/$DEVICE_TYPE/bootlogo.bmp"
BOOTLOGO_NEW="$THEME_DIR/active/image/bootlogo.bmp"

cp "$BOOTLOGO_DEF" "$DC_STO_BOOT_MOUNT/bootlogo.bmp"

while [ -d "$THEME_DIR/active" ]; do
	rm -rf "$THEME_DIR/active"
	sync
	sleep 1
done

unzip "$THEME" -d "$THEME_DIR/active"

if [ "$GC_ADV_RANDOM_THEME" -eq 0 ]; then
	if [ -f "$BOOTLOGO_NEW" ]; then
		cp "$BOOTLOGO_NEW" "$DC_STO_BOOT_MOUNT/bootlogo.bmp"
		if [ "$DEVICE_TYPE" = "rg28xx" ]; then
			convert "$DC_STO_BOOT_MOUNT/bootlogo.bmp" -rotate 270 "$DC_STO_BOOT_MOUNT/bootlogo.bmp"
		fi
	fi
fi

sync
