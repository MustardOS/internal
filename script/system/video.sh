#!/bin/sh

VIDEO_FILE="/opt/muos/startup.mp4"
[ -f "$VIDEO_FILE" ] || exit 1

DURATION=$(ffprobe -v error -select_streams v:0 -show_entries format=duration -of csv=p=0 "$VIDEO_FILE")
DURATION=$(awk 'BEGIN {print int('"$DURATION"') + ('"$DURATION"' > int('"$DURATION"'))}')

[ "$DURATION" -le 10 ] && mpv "$VIDEO_FILE"
