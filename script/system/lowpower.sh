#!/bin/sh

. /opt/muos/script/var/func.sh

IS_IDLE="/tmp/is_idle"

BOARD_DEV=$(GET_VAR "device" "board/name")
CHARGER_DEV=$(GET_VAR "device" "battery/charger")
BATT_CAP=$(GET_VAR "device" "battery/capacity")
BATT_LOW=$(GET_VAR "config" "settings/power/low_battery")
LED_LOW=$(GET_VAR "device" "led/low")
LED_RGB=$(GET_VAR "device" "led/rgb")

LOW_BATTERY_WARNING() {
	if [ "$CHARGING" -eq 0 ] && [ -n "$CAPACITY" ] && [ "$CAPACITY" -le "$BATT_LOW" ]; then
		RGB_ENABLED=$(GET_VAR "config" "settings/general/rgb")
		USING_RGB=0

		if [ "$RGB_ENABLED" -eq 1 ] && [ "$LED_RGB" -eq 1 ] && [ -x "$LED_CONTROL_SCRIPT" ]; then
			case "$BOARD_DEV" in
				rg*) "$LED_CONTROL_SCRIPT" 2 255 255 0 0 ;;
				tui-brick) "$LED_CONTROL_SCRIPT" 1 10 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0 ;;
				tui-spoon) "$LED_CONTROL_SCRIPT" 1 10 255 0 0 255 0 0 255 0 0 ;;
			esac
			USING_RGB=1
		fi

		echo 1 >"$LED_LOW"
		sleep 0.5

		echo 0 >"$LED_LOW"
		sleep 0.5

		[ "$USING_RGB" -eq 1 ] && [ ! -e "$IS_IDLE" ] && LED_CONTROL_CHANGE
	fi
}

while :; do
	read -r CHARGING <"$CHARGER_DEV"
	read -r CAPACITY <"$BATT_CAP"

	LOW_BATTERY_WARNING

	sleep 60
done &
