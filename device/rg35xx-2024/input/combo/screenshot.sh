#!/bin/sh

. /opt/muos/script/var/func.sh

SLEEP_STATE="/tmp/sleep_state"

if [ "$(cat "$SLEEP_STATE")" = "awake" ]; then
	SS_LOCK=/tmp/screenshot.lock

	if [ ! -e "$SS_LOCK" ]; then
		echo 1 >"$(GET_VAR "device" "board/rumble")" && sleep 0.3 && echo 0 >"$(GET_VAR "device" "board/rumble")"

		touch "$SS_LOCK"

		BASE_DIR="/run/muos/storage/screenshot"
		CURRENT_DATE=$(date +"%Y%m%d_%H%M")
		INDEX=0

		while [ -f "${BASE_DIR}/muOS_${CURRENT_DATE}_${INDEX}.png" ]; do
			INDEX=$((INDEX + 1))
		done

		fbgrab -a "${BASE_DIR}/muOS_${CURRENT_DATE}_${INDEX}.png"

		rm "$SS_LOCK"
	fi
fi
