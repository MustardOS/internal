#!/bin/sh

. /opt/muos/script/var/func.sh

SLEEP_STATE="/tmp/sleep_state"

if [ "$(cat "$SLEEP_STATE")" = "awake" ]; then
	SS_LOCK="/tmp/screenshot.lock"

	if [ ! -e "$SS_LOCK" ]; then
		RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"
		SCREEN_WIDTH="$(GET_VAR "device" "screen/width")"
		SCREEN_HEIGHT="$(GET_VAR "device" "screen/height")"
		SCREEN_ROTATE="$(GET_VAR "device" "screen/rotate")"

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

		fbgrab -a -w "$SCREEN_WIDTH" -h "$SCREEN_HEIGHT" -l "$SCREEN_WIDTH" "$SS_FILE"
		[ "$SCREEN_ROTATE" -eq 1 ] && convert "$SS_FILE" -rotate 90 "$SS_FILE"

		rm "$SS_LOCK"
	fi
fi
