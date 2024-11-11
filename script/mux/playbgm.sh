#!/bin/sh

. /opt/muos/script/var/func.sh

MP3_DIR="/run/muos/storage/music"

while :; do
	MP3_FILES=$(find "$MP3_DIR" -maxdepth 1 -type f -name "*.mp3")
	[ -n "$MP3_FILES" ] && mpg123 -Z "$MP3_DIR"/*.mp3
	sleep 1
done &
