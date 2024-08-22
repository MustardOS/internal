#!/bin/sh

. /opt/muos/script/var/func.sh

MP3_DIR="/run/muos/storage/music"

while true; do
	MP3_FILES=$(find "$MP3_DIR" -maxdepth 1 -type f -name "*.mp3")

	if [ -n "$MP3_FILES" ]; then
		mpg123 -Z "$MP3_DIR"/*.mp3
	fi

	sleep 2
done &
