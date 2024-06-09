#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <theme>"
	exit 1
fi

THEME="$1"

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_BOOT=$(parse_ini "$DEVICE_CONFIG" "storage.boot" "mount")
STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

THEMEDIR="$STORE_ROM/MUOS/theme/active"

BOOTLOGO_DEF="/opt/muos/device/$DEVICE/bootlogo.bmp"
BOOTLOGO_NEW="$THEMEDIR/image/bootlogo.bmp"

cp "$BOOTLOGO_DEF" "$STORE_BOOT/bootlogo.bmp"

rm -rf "$THEMEDIR"
unzip "$STORE_ROM/MUOS/theme/$THEME" -d "$THEMEDIR"

if [ -f "$BOOTLOGO_NEW" ]; then
	cp "$BOOTLOGO_NEW" "$STORE_BOOT/bootlogo.bmp"
	if [ "$DEVICE" = "rg28xx" ]; then
		convert "$STORE_BOOT/bootlogo.bmp" -rotate 90
	fi
fi

sync

