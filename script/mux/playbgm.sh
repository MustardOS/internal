#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/global/storage.sh

MP3_DIR="$GC_STO_MUSIC/MUOS/music"

while true; do
	MP3_FILES=$(find "$MP3_DIR" -maxdepth 1 -type f -name "*.mp3")

	if [ -n "$MP3_FILES" ]; then
		mpg123 -Z "$MP3_DIR"/*.mp3
	fi

	sleep 2
done &
