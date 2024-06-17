#!/bin/sh

TMP_POWER_LONG="/tmp/trigger/POWER_LONG"
FG_PROC="/tmp/fg_proc"
DBG="/sys/kernel/debug/dispdbg"
SLEEP_STATE="/tmp/sleep_state"
LED_PATH="/sys/class/power_supply/axp2202-battery/work_led"
LED_STATE="/tmp/work_led_state"

UPDATE_DISPLAY() {
	echo "$2" > "$LED_PATH"
	echo disp0 > "$DBG/name"
	echo blank > "$DBG/command"
	echo "$1" > "$DBG/param"
	echo 1 > "$DBG/start"
}

DEV_WAKE() {
	echo "on" > "$TMP_POWER_LONG"
	echo "awake" > "$SLEEP_STATE"

	if pidof "$FG_PROC_VAL" > /dev/null; then
		pkill -CONT "$FG_PROC_VAL"
	fi

	UPDATE_DISPLAY 0 "$(cat $LED_STATE)"
}

DEV_SLEEP() {
	echo "off" > "$TMP_POWER_LONG"
	echo "sleep" > "$SLEEP_STATE"

	if pidof "$(cat "$FG_PROC")" > /dev/null; then
		pkill -STOP "$(cat "$FG_PROC")"
	fi

	UPDATE_DISPLAY 1 1
}

echo "on" > "$TMP_POWER_LONG"
echo "awake" > "$SLEEP_STATE"

while true; do
	TMP_POWER_LONG_VAL=$(cat "$TMP_POWER_LONG")
	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
	FG_PROC_VAL=$(cat "$FG_PROC")

	if [ "$TMP_POWER_LONG_VAL" = "off" ] && [ "$SLEEP_STATE_VAL" = "awake" ]; then
		if [ "$FG_PROC_VAL" = "retroarch" ] && pidof "$FG_PROC_VAL" > /dev/null; then
			evemu-play /dev/input/event1 < /opt/muos/device/rg35xx-sp/input/emu/ra-savestate
			sleep 0.5
		fi
		if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" > /dev/null; then
   			pkill -STOP "playbgm.sh"
   			killall -q "mp3play"
		fi
		DEV_SLEEP
	fi

	if [ "$TMP_POWER_LONG_VAL" = "on" ] && [ "$SLEEP_STATE_VAL" != "awake" ]; then
		if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" > /dev/null; then
   			pkill -CONT "playbgm.sh"
		fi
		DEV_WAKE
	fi

	sleep 0.25
done

