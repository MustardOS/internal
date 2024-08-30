#!/bin/sh

. /opt/muos/script/var/func.sh

while :; do
	CAP="$(cat "$(GET_VAR "device" "battery/capacity")")"
	LOW=$(GET_VAR "global" "settings/general/low_battery")

	printf "[BATTERY]\tCAPACITY: %s\tLOW INDICATOR: %s\n" "$CAP" "$LOW"

	if [ "$CAP" -le "$LOW" ]; then
		echo 1 >"$(GET_VAR "device" "led/low")"
		sleep 0.5
		echo 0 >"$(GET_VAR "device" "led/low")"
	fi

	sleep 10
done &
