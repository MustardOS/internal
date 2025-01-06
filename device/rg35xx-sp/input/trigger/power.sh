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

			UPDATE_DISPLAY "$(cat $LED_STATE)" 4 0
			;;
	esac
}

echo "on" >"$TMP_POWER_LONG"
echo "awake" >"$SLEEP_STATE"
echo "0" >"$LID_CLOSED_FLAG"

while :; do
	TMP_POWER_LONG_VAL=$(cat "$TMP_POWER_LONG")
	HALL_KEY_VAL=$(cat "$HALL_KEY")
	SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
	LID_CLOSED_FLAG_VAL=$(cat "$LID_CLOSED_FLAG")

	# power button OR lid closed
	if { [ "$TMP_POWER_LONG_VAL" = "off" ] || [ "$HALL_KEY_VAL" = "0" ]; } && [ "$SLEEP_STATE_VAL" = "awake" ]; then
		# HACK: We duplicate this logic from hotkey.sh, but only for the
		# SP. On other devices, power.sh only handles the "Sleep XXs +
		# Shutdown" mode, and hotkey.sh handles the other modes directly.
		#
		# But the SP's lid switch is read via a file (hallkey) that
		# requires polling, whereas the input loop spends most of its
		# time blocked waiting for evdev events. On the SP, power.sh
		# handles *all* shutdown settings in response to lid close.
		#
		# We should move the hallkey polling elsewhere (into muhotkey?)
		# and rework power.sh to only handle "soft sleep" again.
		case "$(GET_VAR global settings/power/shutdown)" in
			# Disabled:
			-2) ;;
			# Sleep Suspend:
			-1) /opt/muos/script/system/suspend.sh power ;;
			# Instant Shutdown:
			2) /opt/muos/script/mux/quit.sh poweroff sleep ;;
			# Sleep XXs + Shutdown:
			*)
				STOP_BGM
				DEV_SLEEP
				;;
		esac
	fi

	# power button with lid open
	if [ "$TMP_POWER_LONG_VAL" = "on" ] && [ "$HALL_KEY_VAL" = "1" ] && [ "$SLEEP_STATE_VAL" != "awake" ]; then
		CHECK_BGM
		DEV_WAKE
	fi

	# lid open after sleep-closed and the lid was previously closed
	if [ "$HALL_KEY_VAL" = "1" ] && [ "$SLEEP_STATE_VAL" = "sleep-closed" ] && [ "$LID_CLOSED_FLAG_VAL" = "1" ]; then
		CHECK_BGM
		DEV_WAKE
	fi

	# update lid closed flag and sleep state when lid is closed and asleep
	#
	# this lets us track lid state transitions (not just current state) and
	# only wake up on lid open if the lid was previously closed
	if [ "$HALL_KEY_VAL" = "0" ] && [ "$SLEEP_STATE_VAL" != awake ]; then
		echo "1" >"$LID_CLOSED_FLAG"
		echo "sleep-closed" >"$SLEEP_STATE"
	fi

	if [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 0 ]; then
		printf "%s" "$(cat $LED_STATE)" >"$(GET_VAR "device" "led/normal")"
	fi

	sleep 1
done
