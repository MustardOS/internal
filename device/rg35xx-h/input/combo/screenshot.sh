#!/bin/sh

. /opt/muos/script/system/parse.sh

SS_LOCK=/tmp/screenshot.lock

if [ ! -e "$SS_LOCK" ]; then
	echo 1 > /sys/class/power_supply/axp2202-battery/moto && sleep 0.25 && echo 0 > /sys/class/power_supply/axp2202-battery/moto

	touch "$SS_LOCK"

	DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
	DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

	STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

	BASE_DIR="$STORE_ROM/MUOS/screenshot"
	CURRENT_DATE=$(date +"%Y%m%d_%H%M")
	INDEX=0

	while [ -f "${BASE_DIR}/muOS_${CURRENT_DATE}_${INDEX}.png" ]; do
		INDEX=$((INDEX + 1))
	done

	fbgrab -a "${BASE_DIR}/muOS_${CURRENT_DATE}_${INDEX}.png"

	rm "$SS_LOCK"
fi

