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

BLBMP="/opt/muos/device/$DEVICE/bootlogo.bmp"

THEMEDIR="$STORE_ROM/MUOS/theme/active"
BOOTLOGO="$THEMEDIR/image/$BLBMP.bmp"

cp "$BLBMP" "$STORE_BOOT/bootlogo.bmp"

rm -rf "$THEMEDIR"
unzip "$STORE_ROM/MUOS/theme/$THEME" -d "$THEMEDIR"

if [ -f "$BOOTLOGO" ]; then
	cp "$BOOTLOGO" "$STORE_BOOT/bootlogo.bmp"
fi

sync

