#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

RANDOM_THEME=$(parse_ini "$CONFIG" "settings.advanced" "random_theme")

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_BOOT=$(parse_ini "$DEVICE_CONFIG" "storage.boot" "mount")
STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

if [ "$1" = "?R" ] && [ "$RANDOM_THEME" -eq 1 ]; then
	THEME=$(find "$STORE_ROM/MUOS/theme" -name '*.zip' | shuf -n 1)
else
	THEME="$STORE_ROM/MUOS/theme/$1.zip"
fi

THEME_DIR="$STORE_ROM/MUOS/theme"

BOOTLOGO_DEF="/opt/muos/device/$DEVICE/bootlogo.bmp"
BOOTLOGO_NEW="$THEME_DIR/active/image/bootlogo.bmp"

cp "$BOOTLOGO_DEF" "$STORE_BOOT/bootlogo.bmp"

while [ -d "$THEME_DIR/active" ]; do
	rm -rf "$THEME_DIR/active"
	sync
	sleep 1
done

unzip "$THEME" -d "$THEME_DIR/active"

if [ "$RANDOM_THEME" -eq 0 ]; then
	if [ -f "$BOOTLOGO_NEW" ]; then
		cp "$BOOTLOGO_NEW" "$STORE_BOOT/bootlogo.bmp"
		if [ "$DEVICE" = "rg28xx" ]; then
			convert "$STORE_BOOT/bootlogo.bmp" -rotate 90
		fi
	fi
fi

sync

