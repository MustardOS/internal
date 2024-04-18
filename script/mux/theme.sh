#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

THEME=$(parse_ini "$CONFIG" "theme" "name")

THEMEDIR="/opt/muos/theme"
BOOTLOGO="$THEMEDIR/image/bootlogo.bmp"

cp "/opt/muos/backup/bootlogo.bmp" "/mnt/boot/bootlogo.bmp"

rm -rf "$THEMEDIR"
unzip "/mnt/mmc/MUOS/theme/$THEME" -d "$THEMEDIR"

if [ -f "$BOOTLOGO" ]; then
	cp "$BOOTLOGO" "/mnt/boot/bootlogo.bmp"
fi

sync

