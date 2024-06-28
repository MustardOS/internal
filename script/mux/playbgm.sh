#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

MP3_DIR="$DC_STO_ROM_MOUNT/MUOS/music"

while true; do
	cd "$MP3_DIR" || exit 1
	MP3_FILES=$(find . -maxdepth 1 -type f -name "*.mp3")

	if [ -n "$MP3_FILES" ]; then
		LINES=$(echo "$MP3_FILES" | wc -l)
		R_LINE=$(awk -v min=1 -v max="$LINES" 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')
		MP3_SELECT=$(echo "$MP3_FILES" | sed -n "${R_LINE}p")

		/opt/muos/bin/mp3play "$MP3_SELECT"
	fi

	sleep 2
done &
