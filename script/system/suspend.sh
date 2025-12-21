#!/bin/sh

. /opt/muos/script/var/func.sh

# Lonely, oh so lonely...
RECENT_WAKE="/tmp/recent_wake"
WAKE_CPU_GOV="/tmp/wake_cpu_gov"

DEV_BOARD=$(GET_VAR "device" "board/name")
HAS_NETWORK=$(GET_VAR "device" "board/network")
CPU_GOV_PATH="$(GET_VAR "device" "cpu/governor")"
LED_RGB="$(GET_VAR "device" "led/rgb")"
RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"
RTC_WAKE_PATH="$(GET_VAR "device" "board/rtc_wake")"
MAX_BRIGHT=$(GET_VAR "device" "screen/bright")

RGB_ENABLE=$(GET_VAR "config" "settings/general/rgb")
RUMBLE_SETTING="$(GET_VAR "config" "settings/advanced/rumble")"
SUSPEND_STATE="$(GET_VAR "config" "danger/state")"
DEFAULT_BRIGHTNESS="$(GET_VAR "config" "settings/general/brightness")"
SHUTDOWN_TIME_SETTING="$(GET_VAR "config" "settings/power/shutdown")"
CONNECT_ON_WAKE=$(GET_VAR "config" "settings/network/wake")
USE_ACTIVITY="$(GET_VAR "config" "settings/advanced/activity")"

ACTIVITY_TRACKER() {
	ROM_GO="/tmp/rom_go"
	if [ -e "$ROM_GO" ]; then
		{
			read -r NAME
			read -r CORE
			read -r _
			read -r _
			read -r _
			read -r _
			read -r R_DIR1
			read -r R_DIR2
			read -r ROM_NAME
		} <"$ROM_GO"

		R_DIR="$R_DIR1$R_DIR2"
		ROM="$R_DIR/$ROM_NAME"

		case "$1" in
			start) [ "${USE_ACTIVITY:-0}" -eq 1 ] && /opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" start ;;
			stop) [ "${USE_ACTIVITY:-0}" -eq 1 ] && /opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" stop ;;
		esac
	fi
}

CHECK_RA_AND_SAVE() {
	# This is the safest bet to get RetroArch to save state automatically
	# if the user has configured their settings to do so...

	[ "$(GET_VAR "system" "foreground_process")" = "retroarch" ] && /usr/bin/retroarch --command "$1"

	# If you're reading this and thinking "WhAt AbOuT pOrTmAsTeR gAmEs?"
	# My answer is, you find out how to restore save game content and let us know!
}

SLEEP() {
	ACTIVITY_TRACKER stop

	CHECK_RA_AND_SAVE "SAVE_STATE"
	CHECK_RA_AND_SAVE "MENU_TOGGLE"

	touch "$RECENT_WAKE"

	DISPLAY_WRITE lcd0 setbl 0
	amixer set "Master" mute

	cat "$CPU_GOV_PATH" >"$WAKE_CPU_GOV"

	if [ "$RGB_ENABLE" -eq 1 ] && [ "$LED_RGB" -eq 1 ]; then
		[ -f "$LED_CONTROL_SCRIPT" ] && "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
	fi

	case "$RUMBLE_SETTING" in
		3 | 5 | 6) RUMBLE "$RUMBLE_DEVICE" 0.3 ;;
	esac

	if [ "$HAS_NETWORK" -eq 1 ]; then
		nohup /opt/muos/script/system/network.sh disconnect >/dev/null 2>&1 &
	fi

	/opt/muos/script/device/module.sh unload

	echo "$SUSPEND_STATE" >"/sys/power/state"

	sleep 0.5
}

RESUME() {
	/opt/muos/script/device/module.sh load

	LED_CONTROL_CHANGE

	E_BRIGHT="$DEFAULT_BRIGHTNESS"

	# Some display panels don't like to resume on lower backlights due
	# to potential voltage lines or some shit... so let's resume on
	# a bit more brightness unfortunately!
	[ "$E_BRIGHT" -le 8 ] && E_BRIGHT=16

	# We're going to do this twice because of how our brightness script
	# works with existing integer values.  It's a precise system!
	B=0
	while [ $B -lt 2 ]; do
		# Pick +1 or -1 randomly... and no $RANDOM is not posix!
		if [ $(($(od -An -N2 -tu2 /dev/urandom | tr -d ' ') % 2)) -eq 0 ]; then
			E_BRIGHT=$((E_BRIGHT + 1))
		else
			E_BRIGHT=$((E_BRIGHT - 1))
		fi

		[ "$E_BRIGHT" -gt "$MAX_BRIGHT" ] && E_BRIGHT="$((MAX_BRIGHT - 16))"

		/opt/muos/script/device/bright.sh "$E_BRIGHT"
		B=$((B + 1))
	done

	[ "$USB_FUNCTION" != "none" ] && /opt/muos/script/system/usb_gadget.sh resume

	amixer set "Master" unmute
	CHECK_RA_AND_SAVE "MENU_TOGGLE"

	# Some stupid TrimUI GPU shenanigans
	case "$DEV_BOARD" in
		tui*) setalpha 0 ;;
	esac

	cat "$WAKE_CPU_GOV" >"$CPU_GOV_PATH"
	rm -rf "/tmp/wake_cpu_gov"

	# We're going to wait for 5 seconds to stop sleep suspend from triggering again
	(sleep 5 && rm "$RECENT_WAKE") &

	if [ "$HAS_NETWORK" -eq 1 ]; then
		[ "$CONNECT_ON_WAKE" -eq 1 ] && nohup /opt/muos/script/system/network.sh connect >/dev/null 2>&1 &
	fi

	ACTIVITY_TRACKER start
}

[ -f "$RECENT_WAKE" ] && exit 0

case "$SHUTDOWN_TIME_SETTING" in
	-2) ;;
	-1) SLEEP && RESUME ;;
	2)
		CHECK_RA_AND_SAVE "CLOSE_CONTENT"
		/opt/muos/script/mux/quit.sh poweroff sleep
		;;
	*)
		S_EPOCH="$RTC_WAKE_PATH/since_epoch"
		W_ALARM="$RTC_WAKE_PATH/wakealarm"

		CURRENT_EPOCH=$(cat "$S_EPOCH")
		WAKE_EPOCH=$((CURRENT_EPOCH + SHUTDOWN_TIME_SETTING))
		echo "$WAKE_EPOCH" >"$W_ALARM"

		SLEEP

		CURRENT_TIME=$(cat "$S_EPOCH")
		if [ "$CURRENT_TIME" -ge "$WAKE_EPOCH" ]; then
			CHECK_RA_AND_SAVE "CLOSE_CONTENT"
			/opt/muos/script/mux/quit.sh poweroff sleep
		else
			RESUME
		fi

		echo 0 >"$W_ALARM"
		;;
esac
