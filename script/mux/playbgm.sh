#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

MP3_DIR="$STORE_ROM/MUOS/music"

while true; do
	cd "$MP3_DIR" || exit 1
	MP3_FILES=$(find . -maxdepth 1 -type f -name "*.mp3")

	if [ -n "$MP3_FILES" ]; then
		LINES=$(echo "$MP3_FILES" | wc -l)
		R_LINE=$(awk -v min=1 -v max="$LINES" 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
		MP3_SELECT=$(echo "$MP3_FILES" | sed -n "${R_LINE}p")

		/opt/muos/bin/mp3play "$MP3_SELECT"
	fi

	sleep 3
done &
