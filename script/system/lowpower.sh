#!/bin/sh

. /opt/muos/script/var/func.sh

while :; do
	if [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 0 ]; then
		if [ "$(cat "$(GET_VAR "device" "battery/capacity")")" -le "$(GET_VAR "config" "settings/power/low_battery")" ]; then
			if [ "$(GET_VAR "config" "settings/general/rgb")" -eq 1 ] && [ "$(GET_VAR "device" "led/rgb")" -eq 1 ]; then
				if [ "$LED_RGB" -eq 1 ]; then

					case "$(GET_VAR "device" "board/name")" in
						rg*) /opt/muos/device/script/led_control.sh 2 255 255 0 0 ;;
						tui-brick) /opt/muos/device/script/led_control.sh 1 10 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0 ;;
						tui-spoon) /opt/muos/device/script/led_control.sh 1 10 255 0 0 255 0 0 255 0 0 ;;
						*) ;;

					esac
				fi
			fi

			echo 1 >"$(GET_VAR "device" "led/low")"
			/opt/muos/bin/toybox sleep 0.5

			echo 0 >"$(GET_VAR "device" "led/low")"
			/opt/muos/bin/toybox sleep 0.5
		fi

		if [ "$(GET_VAR "config" "settings/general/rgb")" -eq 1 ] && [ "$(GET_VAR "device" "led/rgb")" -eq 1 ]; then
			/run/muos/storage/theme/active/rgb/rgbconf.sh
		fi
	fi
	/opt/muos/bin/toybox sleep 10
done &
