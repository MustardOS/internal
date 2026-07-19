#!/bin/sh

. /opt/muos/script/var/func.sh

BATT_OVL="$MUOS_RUN_DIR/overlay.battery"
BATT_CAP="$MUOS_RUN_DIR/battery/capacity"
BATT_CHG="$MUOS_RUN_DIR/battery/charging"

BOARD_NAME=$(GET_VAR "device" "board/name")
LED_LOW=$(GET_VAR "device" "led/low")
LED_RGB=$(GET_VAR "device" "led/rgb")

LED_CMD=""
if [ "$LED_RGB" -eq 1 ] && [ -x "$MUOS_RGB_BIN" ]; then
	case "$BOARD_NAME" in
		rg*) LED_CMD="$MUOS_RGB_BIN -b SERIAL 1 255 255 0 0 255 0 0" ;;
		tui-brick) LED_CMD="$MUOS_RGB_BIN -b SYSFS 1 10 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0" ;;
		tui-brick-pro) LED_CMD="$MUOS_RGB_BIN -b SYSFS 1 10 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0 255 0 0" ;;
		tui-spoon) LED_CMD="$MUOS_RGB_BIN -b SYSFS 1 10 255 0 0 255 0 0 255 0 0" ;;
	esac
fi

OVERLAY_ACTIVE=0

LOW_BATTERY_WARNING() {
	read -r CHARGING <"$BATT_CHG"
	read -r CAPACITY <"$BATT_CAP"

	if [ "$CHARGING" -ne 0 ] || [ "$CAPACITY" -gt "$(GET_VAR "config" "settings/power/low_battery")" ]; then
		if [ "$OVERLAY_ACTIVE" -eq 1 ]; then
			rm -f "$BATT_OVL"
			echo 0 >"$LED_LOW"
			OVERLAY_ACTIVE=0
		fi
		return
	fi

	if [ "$OVERLAY_ACTIVE" -eq 0 ]; then
		touch "$BATT_OVL"
		echo 1 >"$LED_LOW"
		OVERLAY_ACTIVE=1

		if [ -n "$LED_CMD" ] && [ "$(GET_VAR "config" "settings/general/rgb")" -eq 1 ]; then
			$LED_CMD
			[ ! -e "$IS_IDLE" ] && LED_CONTROL_CHANGE restore
		fi
	fi
}

until [ -f "$BATT_CAP" ] && [ -f "$BATT_CHG" ]; do
	sleep 2
done

while :; do
	LOW_BATTERY_WARNING
	sleep 30
done &
