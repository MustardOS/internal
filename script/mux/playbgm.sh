#!/bin/sh

. /opt/muos/script/var/func.sh

BGM_GLOBAL_DIR="/run/muos/storage/music"
BGM_THEME_DIR="/run/muos/storage/theme/active/music"

BGM_TYPE=$(GET_VAR "global" "settings/general/bgm")

while :; do
	case $BGM_TYPE in
		0) exit 0 ;;
		1) BGM_FILE=$(find "$BGM_GLOBAL_DIR" -maxdepth 1 -type f 2>/dev/null | shuf -n 1) ;;
		2) BGM_FILE=$(find "$BGM_THEME_DIR" -maxdepth 1 -type f 2>/dev/null | shuf -n 1) ;;
	esac

	mpv --no-video "$BGM_FILE" >/dev/null 2>&1

	sleep 1
done &
