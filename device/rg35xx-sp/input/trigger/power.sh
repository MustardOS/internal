#!/bin/sh

. /opt/muos/script/var/func.sh

TMP_POWER_LONG="/tmp/trigger/POWER_LONG"

HALL_KEY="/sys/class/power_supply/axp2202-battery/hallkey"
SLEEP_STATE="/tmp/sleep_state"
LED_STATE="/tmp/work_led_state"
LID_CLOSED_FLAG="/tmp/lid_closed_flag"

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

			UPDATE_DISPLAY "$(cat $LED_STATE)" 0 "$(GET_VAR "global" "settings/general/brightness")"
			;;
	esac
}

DEV_SLEEP() {
	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
	case "$(cat "$FG_PROC_VAL")" in
		fbpad | muxcharge | muxstart) ;;
		*)
			echo "off" >"$TMP_POWER_LONG"

			if [ "$(cat "$HALL_KEY")" = "0" ]; then
				echo "sleep-closed" >"$SLEEP_STATE"
				echo "1" >"$LID_CLOSED_FLAG" # Lid was closed
			else
				echo "sleep-open" >"$SLEEP_STATE"
				echo "0" >"$LID_CLOSED_FLAG" # Lid was open
			fi

			/opt/muos/script/system/suspend.sh sleep

			if pidof "$FG_PROC_VAL" >/dev/null; then
				pkill -STOP "$FG_PROC_VAL"
			fi

			UPDATE_DISPLAY 1 4 0
			;;
	esac
}

echo "on" >"$TMP_POWER_LONG"
echo "awake" >"$SLEEP_STATE"
echo "0" >"$LID_CLOSED_FLAG"

while true; do
	TMP_POWER_LONG_VAL=$(cat "$TMP_POWER_LONG")
	HALL_KEY_VAL=$(cat "$HALL_KEY")
	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
	LID_CLOSED_FLAG_VAL=$(cat "$LID_CLOSED_FLAG")

	# power button OR lid closed
	if { [ "$TMP_POWER_LONG_VAL" = "off" ] || [ "$HALL_KEY_VAL" = "0" ]; } && [ "$SLEEP_STATE_VAL" = "awake" ]; then
		if pgrep -f "playbgm.sh" >/dev/null; then
			pkill -STOP "playbgm.sh"
			killall -q "mpg123"
		fi
		DEV_SLEEP
	fi

	# power button with lid open
	if [ "$TMP_POWER_LONG_VAL" = "on" ] && [ "$HALL_KEY_VAL" = "1" ] && [ "$SLEEP_STATE_VAL" != "awake" ]; then
		if pgrep -f "playbgm.sh" >/dev/null; then
			pkill -CONT "playbgm.sh"
		fi
		DEV_WAKE
	fi

	# lid open after sleep-closed and the lid was previously closed
	if [ "$HALL_KEY_VAL" = "1" ] && [ "$SLEEP_STATE_VAL" = "sleep-closed" ] && [ "$LID_CLOSED_FLAG_VAL" = "1" ]; then
		if pgrep -f "playbgm.sh" >/dev/null; then
			pkill -CONT "playbgm.sh"
		fi
		DEV_WAKE
	fi

	# update lid closed flag and sleep state when lid is closed
	if [ "$HALL_KEY_VAL" = "0" ]; then
		echo "1" >"$LID_CLOSED_FLAG"
		echo "sleep-closed" >"$SLEEP_STATE"
	fi

	# what a pain in the arse this script was
	sleep 0.25
done
