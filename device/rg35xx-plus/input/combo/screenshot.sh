#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/global/storage.sh

SLEEP_STATE="/tmp/sleep_state"
SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")

if [ "$SLEEP_STATE_VAL" = "awake" ]; then
	SS_LOCK=/tmp/screenshot.lock

	if [ ! -e "$SS_LOCK" ]; then
		echo 1 >/sys/class/power_supply/axp2202-battery/moto && sleep 0.25 && echo 0 >/sys/class/power_supply/axp2202-battery/moto

		touch "$SS_LOCK"

		BASE_DIR="$(GET_VAR "global" "storage/screenshot")/MUOS/screenshot"
		CURRENT_DATE=$(date +"%Y%m%d_%H%M")
		INDEX=0

		while [ -f "${BASE_DIR}/muOS_${CURRENT_DATE}_${INDEX}.png" ]; do
			INDEX=$((INDEX + 1))
		done

		fbgrab -a "${BASE_DIR}/muOS_${CURRENT_DATE}_${INDEX}.png"

		rm "$SS_LOCK"
	fi
fi
