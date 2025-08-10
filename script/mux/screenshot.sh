#!/bin/sh

. /opt/muos/script/var/func.sh

SS_LOCK="/tmp/screenshot.lock"

if [ ! -e "$SS_LOCK" ]; then
	RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"
	SCREEN_WIDTH="$(GET_VAR "device" "screen/width")"
	SCREEN_HEIGHT="$(GET_VAR "device" "screen/height")"

	RUMBLE "$RUMBLE_DEVICE" 0.3

	touch "$SS_LOCK"

	BASE_DIR="/run/muos/storage/screenshot"
	CURRENT_DATE="$(date +"%Y%m%d_%H%M")"
	INDEX=0

	while :; do
		SS_FILE="${BASE_DIR}/muOS_${CURRENT_DATE}_${INDEX}.png"
		[ ! -f "$SS_FILE" ] && break
		INDEX=$((INDEX + 1))
	done

	# Silly 28xx...
	case "$(GET_VAR "device" "board/name")" in
		rg28xx-h) fbgrab -a -w "$SCREEN_HEIGHT" -h "$SCREEN_WIDTH" -l "$SCREEN_HEIGHT" "$SS_FILE" && convert "$SS_FILE" -rotate 90 "$SS_FILE" ;;
		*) fbgrab -a -w "$SCREEN_WIDTH" -h "$SCREEN_HEIGHT" -l "$SCREEN_WIDTH" "$SS_FILE" ;;
	esac

	rm "$SS_LOCK"
fi
