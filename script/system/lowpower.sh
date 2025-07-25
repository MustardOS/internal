#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_DEV=$(GET_VAR "device" "board/name")
CHARGER_DEV=$(GET_VAR "device" "battery/charger")
BATT_CAP=$(GET_VAR "device" "battery/capacity")
BATT_LOW=$(GET_VAR "config" "settings/power/low_battery")
LED_LOW=$(GET_VAR "device" "led/low")
LED_RGB=$(GET_VAR "device" "led/rgb")
LED_CONTROL_SCRIPT="/opt/muos/device/script/led_control.sh"

LOW_BATTERY_WARNING() {
	RGB_ENABLED=$(GET_VAR "config" "settings/general/rgb")

	if [ "$CHARGING" -eq 0 ] && [ -n "$CAPACITY" ] && [ "$CAPACITY" -le "$BATT_LOW" ]; then
		if [ "$RGB_ENABLED" -eq 1 ] && [ "$LED_RGB" -eq 1 ] && [ -x "$LED_CONTROL_SCRIPT" ]; then
			case "$BOARD_DEV" in
				rg*) "$LED_CONTROL_SCRIPT" 2 255 255 0 0 ;;
				tui-brick) "$LED_CONTROL_SCRIPT" 1 10 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0 ;;
				tui-spoon) "$LED_CONTROL_SCRIPT" 1 10 255 0 0 255 0 0 255 0 0 ;;
			esac
		fi

		echo 1 >"$LED_LOW"
		/opt/muos/bin/toybox sleep 0.5

		echo 0 >"$LED_LOW"
		/opt/muos/bin/toybox sleep 0.5
	fi
}

while :; do
	read -r CHARGING <"$CHARGER_DEV"
	read -r CAPACITY <"$BATT_CAP"

	LOW_BATTERY_WARNING
	LED_CONTROL_CHANGE

	/opt/muos/bin/toybox sleep 60
done &
