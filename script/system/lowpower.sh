#!/bin/sh

. /opt/muos/script/var/func.sh

IS_IDLE="$MUOS_RUN_DIR/is_idle"
BATT_OVERLAY="$MUOS_RUN_DIR/overlay.battery"

BOARD_NAME=$(GET_VAR "device" "board/name")
CHARGER_DEV=$(GET_VAR "device" "battery/charger")
BATT_CAP=$(GET_VAR "device" "battery/capacity")
BATT_LOW=$(GET_VAR "config" "settings/power/low_battery")
LED_LOW=$(GET_VAR "device" "led/low")
LED_RGB=$(GET_VAR "device" "led/rgb")

LOW_BATTERY_WARNING() {
	if [ "$CHARGING" -eq 0 ] && [ -n "$CAPACITY" ] && [ "$CAPACITY" -le "$BATT_LOW" ]; then
		[ -e "$BATT_OVERLAY" ] || touch "$BATT_OVERLAY"

		RGB_ENABLED=$(GET_VAR "config" "settings/general/rgb")
		USING_RGB=0

		if [ "$RGB_ENABLED" -eq 1 ] && [ "$LED_RGB" -eq 1 ] && [ -x "$LED_CONTROL_SCRIPT" ]; then
			case "$BOARD_NAME" in
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
	else
		rm "$BATT_OVERLAY"
	fi
}

while :; do
	read -r CHARGING <"$CHARGER_DEV"
	read -r CAPACITY <"$BATT_CAP"

	BATT_LOW=$(GET_VAR "config" "settings/power/low_battery")

	LOW_BATTERY_WARNING

	sleep 30
done &
