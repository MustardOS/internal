#!/bin/sh

trap "killall mpv; exit 0" TERM

while :; do
	BGM_FILE=$(find "$1" -maxdepth 1 -type f 2>/dev/null | shuf -n 1)
	if [ -n "$BGM_FILE" ]; then
		mpv --no-video "$BGM_FILE" >/dev/null 2>&1
	else
		sleep 1
	fi
done
