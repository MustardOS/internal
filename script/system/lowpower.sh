#!/bin/sh

. /opt/muos/script/var/func.sh

while :; do
	if [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 0 ]; then
		if [ "$(cat "$(GET_VAR "device" "battery/capacity")")" -le "$(GET_VAR "global" "settings/power/low_battery")" ]; then
			echo 1 >"$(GET_VAR "device" "led/low")"
			sleep 0.5
			echo 0 >"$(GET_VAR "device" "led/low")"
		fi

		sleep 10
	fi
done &
