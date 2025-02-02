#!/bin/sh

. /opt/muos/script/var/func.sh

TMP_POWER_LONG="/tmp/trigger/POWER_LONG"

SLEEP_STATE="/tmp/sleep_state"
LED_STATE="/tmp/work_led_state"

UPDATE_DISPLAY() {
	echo "$1" >"$(GET_VAR "device" "led/normal")"
	echo "$2" >/sys/class/graphics/fb0/blank
	DISPLAY_WRITE lcd0 setbl "$3"
}

DEV_WAKE() {
	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
	case "$FG_PROC_VAL" in
		fbpad | muxcharge | muxstart) ;;
		*)
			echo "on" >"$TMP_POWER_LONG"
			echo "awake" >"$SLEEP_STATE"

			/opt/muos/script/system/suspend.sh resume

			if pidof "$FG_PROC_VAL" >/dev/null; then
				pkill -CONT "$FG_PROC_VAL"
			fi

			BRIGHTNESS=$(GET_VAR "global" "settings/general/brightness")
			if [ -z "$BRIGHTNESS" ] || [ "$BRIGHTNESS" -lt 10 ]; then
				UPDATE_DISPLAY "$(cat "$LED_STATE")" 0 10
				/opt/muos/device/current/input/combo/bright.sh 10
			else
				UPDATE_DISPLAY "$(cat "$LED_STATE")" 0 "$BRIGHTNESS"
				/opt/muos/device/current/input/combo/bright.sh "$BRIGHTNESS"
			fi
			;;
	esac
}

DEV_SLEEP() {
	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
	case "$FG_PROC_VAL" in
		fbpad | muxcharge | muxstart) ;;
		*)
			echo "off" >"$TMP_POWER_LONG"
			echo "sleep" >"$SLEEP_STATE"

			/opt/muos/script/system/suspend.sh sleep

			if pidof "$FG_PROC_VAL" >/dev/null; then
				pkill -STOP "$FG_PROC_VAL"
			fi

			UPDATE_DISPLAY "$(cat $LED_STATE)" 4 0
			;;
	esac
}

echo "on" >"$TMP_POWER_LONG"
echo "awake" >"$SLEEP_STATE"

while :; do
	TMP_POWER_LONG_VAL=$(cat "$TMP_POWER_LONG")
	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")

	if [ "$TMP_POWER_LONG_VAL" = "off" ] && [ "$SLEEP_STATE_VAL" = "awake" ]; then
		STOP_BGM
		DEV_SLEEP
	fi

	if [ "$TMP_POWER_LONG_VAL" = "on" ] && [ "$SLEEP_STATE_VAL" != "awake" ]; then
		CHECK_BGM
		DEV_WAKE
	fi

	if [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 0 ]; then
		printf "%s" "$(cat $LED_STATE)" >"$(GET_VAR "device" "led/normal")"
	fi

	sleep 1
done
