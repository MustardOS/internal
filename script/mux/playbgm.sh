#!/bin/sh

. /opt/muos/script/var/func.sh

BGM_GLOBAL_DIR="/run/muos/storage/music"
BGM_THEME_DIR="/run/muos/storage/theme/active/music"

BGM_TYPE=$(GET_VAR "global" "settings/general/bgm")

PLAY_RANDOM_BGM() {
	DIR="$1"
	if [ -d "$DIR" ]; then
		while true; do
			BGM_FILE=$(find "$DIR" -maxdepth 1 -type f 2>/dev/null | shuf -n 1)

			if [ -n "$BGM_FILE" ]; then
				mpv --no-video "$BGM_FILE" >/dev/null 2>&1
			else
				sleep 1
			fi
		done
	fi
}

while :; do
	case $BGM_TYPE in
		0) exit 0 ;;
		1) PLAY_RANDOM_BGM "$BGM_GLOBAL_DIR" ;;
		2) PLAY_RANDOM_BGM "$BGM_THEME_DIR" ;;
	esac

	sleep 1
done
