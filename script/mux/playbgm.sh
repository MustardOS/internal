#!/bin/sh

. /opt/muos/script/var/func.sh

BGM_GLOBAL_DIR="/run/muos/storage/music"
BGM_THEME_DIR="/run/muos/storage/theme/active/music"

BGM_TYPE=$(GET_VAR "global" "settings/general/bgm")

PLAY_RANDOM_BGM() {
	DIR="$1"
	if [ -d "$DIR" ]; then
		find "$DIR" -maxdepth 1 -type f | shuf -n 1 | while IFS= read -r BGM_FILE; do
			mpv "$BGM_FILE"
		done
	fi
}

while :; do
	case $BGM_TYPE in
		1) PLAY_RANDOM_BGM "$BGM_GLOBAL_DIR" ;;
		2) PLAY_RANDOM_BGM "$BGM_THEME_DIR" ;;
	esac

	# Have a wee nap...
	sleep 1
done &
