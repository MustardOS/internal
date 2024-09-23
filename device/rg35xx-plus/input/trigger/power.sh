#!/bin/sh

. /opt/muos/script/var/func.sh

TMP_POWER_LONG="/tmp/trigger/POWER_LONG"

SLEEP_STATE="/tmp/sleep_state"
LED_STATE="/tmp/work_led_state"
TMP_BRIGHT="/tmp/tmp_bright_value"

UPDATE_DISPLAY() {
	echo "$1" >"$(GET_VAR "device" "led/normal")"
	echo "$2" >/sys/class/graphics/fb0/blank
	DISPLAY_WRITE lcd0 setbl "$3"
}

DEV_WAKE() {
	case "$FG_PROC_VAL" in
		fbpad | muxcharge | muxstart) ;;
		*)
			FG_PROC_VAL=$(GET_VAR "system" "foreground_process")

			echo "on" >"$TMP_POWER_LONG"
			echo "awake" >"$SLEEP_STATE"

			/opt/muos/script/system/suspend.sh resume

			if pidof "$FG_PROC_VAL" >/dev/null; then
				pkill -CONT "$FG_PROC_VAL"
			fi

			UPDATE_DISPLAY "$(cat $LED_STATE)" 0 "$(cat $TMP_BRIGHT)"
			;;
	esac
}

DEV_SLEEP() {
	case "$FG_PROC_VAL" in
		fbpad | muxcharge | muxstart) ;;
		*)
			FG_PROC_VAL=$(GET_VAR "system" "foreground_process")

			echo "off" >"$TMP_POWER_LONG"
			echo "sleep" >"$SLEEP_STATE"

			/opt/muos/script/system/suspend.sh sleep

			if pidof "$FG_PROC_VAL" >/dev/null; then
				pkill -STOP "$FG_PROC_VAL"
			fi

			printf "%s" "$(DISPLAY_READ lcd0 getbl)" >$TMP_BRIGHT
			UPDATE_DISPLAY 1 4 0
			;;
	esac
}

echo "on" >"$TMP_POWER_LONG"
echo "awake" >"$SLEEP_STATE"

while true; do
	TMP_POWER_LONG_VAL=$(cat "$TMP_POWER_LONG")
	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")

	if [ "$TMP_POWER_LONG_VAL" = "off" ] && [ "$SLEEP_STATE_VAL" = "awake" ]; then
		if pgrep -f "playbgm.sh" >/dev/null; then
			pkill -STOP "playbgm.sh"
			killall -q "mpg123"
		fi
		DEV_SLEEP
	fi

	if [ "$TMP_POWER_LONG_VAL" = "on" ] && [ "$SLEEP_STATE_VAL" != "awake" ]; then
		if pgrep -f "playbgm.sh" >/dev/null; then
			pkill -CONT "playbgm.sh"
		fi
		DEV_WAKE
	fi

	sleep 0.25
done
