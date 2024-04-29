#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
	BLBMP=bootlogo-alt
else
	BLBMP=bootlogo
fi

THEME=$(parse_ini "$CONFIG" "theme" "name")

THEMEDIR="/opt/muos/theme"
BOOTLOGO="$THEMEDIR/image/$BLBMP.bmp"

cp "/opt/muos/backup/$BLBMP.bmp" "/mnt/boot/bootlogo.bmp"

rm -rf "$THEMEDIR"
unzip "/mnt/mmc/MUOS/theme/$THEME" -d "$THEMEDIR"

if [ -f "$BOOTLOGO" ]; then
	cp "$BOOTLOGO" "/mnt/boot/bootlogo.bmp"
fi

sync

