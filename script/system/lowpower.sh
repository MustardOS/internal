#!/bin/sh

. /opt/muos/script/var/func.sh

CHA="$(cat "$(GET_VAR "device" "battery/charger")")"
CAP="$(cat "$(GET_VAR "device" "battery/capacity")")"
LOW=$(GET_VAR "global" "settings/power/low_battery")

LOG_INFO "$0" 0 "BATTERY" "CAPACITY: %s\tLOW INDICATOR: %s\n" "$CAP" "$LOW"

while :; do
	if [ "$CAP" -le "$LOW" ] && [ "$CHA" -eq 0 ]; then
		LOG_INFO "$0" 0 "BATTERY" "CAPACITY: %s\tLOW INDICATOR: %s\n" "$CAP" "$LOW"

		echo 1 >"$(GET_VAR "device" "led/low")"
		sleep 0.5
		echo 0 >"$(GET_VAR "device" "led/low")"
	fi

	sleep 10
done &
