#!/bin/sh

. /opt/muos/script/var/func.sh

while :; do
	if [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 0 ]; then
		if [ "$(cat "$(GET_VAR "device" "battery/capacity")")" -le "$(GET_VAR "global" "settings/power/low_battery")" ]; then
			if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
				/opt/muos/device/current/script/led_control.sh 2 255 255 0 0
			fi					
			echo 1 >"$(GET_VAR "device" "led/low")"
			sleep 0.5
			echo 0 >"$(GET_VAR "device" "led/low")"
		else
			if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
				/run/muos/storage/theme/active/rgb/rgbconf.sh
			fi
		fi
	fi
 	sleep 10
done &
