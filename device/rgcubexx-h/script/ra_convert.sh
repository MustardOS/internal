#!/bin/sh

RA_KV="
audio_sync:false
video_fullscreen:false
video_refresh_rate:58.65
video_threaded:false
video_vsync:false
"

RA_CONFIG="/run/muos/storage/retroarch/retroarch.default.cfg"
printf "%s\n" "$RA_KV" | while IFS=: read -r KEY VALUE; do
	sed -i "/^$KEY = /d" "$RA_CONFIG"
	printf '%s = "%s"\n' "$KEY" "$VALUE" >>"$RA_CONFIG"
done

CONFIG_DIR="/run/muos/storage/info/config"
find "$CONFIG_DIR" -type f -name "*.cfg" | while IFS= read -r FILE; do
	printf "%s\n" "$RA_KV" | while IFS=: read -r KEY VALUE; do
		sed -i "/^$KEY = /d" "$FILE"
		printf '%s = "%s"\n' "$KEY" "$VALUE" >>"$FILE"
	done
done
