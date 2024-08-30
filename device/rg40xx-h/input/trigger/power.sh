#!/bin/sh

. /opt/muos/script/var/func.sh

TMP_POWER_LONG="/tmp/trigger/POWER_LONG"

SLEEP_STATE="/tmp/sleep_state"
LED_STATE="/tmp/work_led_state"

UPDATE_DISPLAY() {
	echo "$2" >"$(GET_VAR "device" "led/normal")"
	DISPLAY_WRITE disp0 blank "$1"
}

DEV_WAKE() {
	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")

	echo "on" >"$TMP_POWER_LONG"
	echo "awake" >"$SLEEP_STATE"

	/opt/muos/script/system/suspend.sh resume

	if pidof "$FG_PROC_VAL" >/dev/null; then
		pkill -CONT "$FG_PROC_VAL"
	fi

	UPDATE_DISPLAY 0 "$(cat $LED_STATE)"
}

DEV_SLEEP() {
	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")

	echo "off" >"$TMP_POWER_LONG"
	echo "sleep" >"$SLEEP_STATE"

	/opt/muos/script/system/suspend.sh sleep

	if pidof "$FG_PROC_VAL" >/dev/null; then
		pkill -STOP "$FG_PROC_VAL"
	fi

	UPDATE_DISPLAY 1 1
}

echo "on" >"$TMP_POWER_LONG"
echo "awake" >"$SLEEP_STATE"

while true; do
	TMP_POWER_LONG_VAL=$(cat "$TMP_POWER_LONG")
	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")

	if [ "$TMP_POWER_LONG_VAL" = "off" ] && [ "$SLEEP_STATE_VAL" = "awake" ]; then
		if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
			pkill -STOP "playbgm.sh"
			killall -q "mpg123"
		fi
		DEV_SLEEP
	fi

	if [ "$TMP_POWER_LONG_VAL" = "on" ] && [ "$SLEEP_STATE_VAL" != "awake" ]; then
		if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
			pkill -CONT "playbgm.sh"
		fi
		DEV_WAKE
	fi

	sleep 0.25
done
