#!/bin/sh

. /opt/muos/script/var/func.sh

# Lonely, oh so lonely...
RECENT_WAKE="$MUOS_RUN_DIR/recent_wake"
WAKE_CPU_GOV="$MUOS_RUN_DIR/wake_cpu_gov"
LED_STATE="$MUOS_RUN_DIR/work_led_state"

RECENT_WAKE="$MUOS_RUN_DIR/recent_wake"
RECENT_WAKE_GRACE="${RECENT_WAKE_GRACE:-6}"
RECENT_WAKE_STALE="${RECENT_WAKE_STALE:-60}"

BOARD_NAME=$(GET_VAR "device" "board/name")
HAS_NETWORK=$(GET_VAR "device" "board/network")
CPU_GOV_PATH="$(GET_VAR "device" "cpu/governor")"
LED_NORMAL="$(GET_VAR "device" "led/normal")"
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
USB_FUNCTION="$(GET_VAR "config" "settings/advanced/usb_function")"

UPTIME_SEC() {
	U=$(cut -d ' ' -f 1 /proc/uptime 2>/dev/null || echo 0)
	U=${U%%.*}
	[ -n "$U" ] || U=0
	printf '%s\n' "$U"
}

RECENT_WAKE_SET() {
	[ -f "$RECENT_WAKE" ] || return 1

	T=0
	read -r T <"$RECENT_WAKE" 2>/dev/null || T=0
	T=${T%%.*}
	[ -n "$T" ] || T=0

	NOW="$(UPTIME_SEC)"
	AGE=$((NOW - T))

	# If clock went backwards(?!) or file is stale fuck it off
	if [ "$AGE" -lt 0 ] || [ "$AGE" -ge "$RECENT_WAKE_STALE" ]; then
		rm -f "$RECENT_WAKE" 2>/dev/null || :
		return 1
	fi

	return 0
}

RECENT_WAKE_MARK() {
	UPTIME_SEC >"$RECENT_WAKE"
}

RECENT_WAKE_CLEAR_LATER() {
	# Use nohup so it survives parent exit reliably!
	nohup sh -c "sleep \"$RECENT_WAKE_GRACE\"; rm -f \"$RECENT_WAKE\"" >/dev/null 2>&1 &
}

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
	RECENT_WAKE_MARK

	ACTIVITY_TRACKER stop

	CHECK_RA_AND_SAVE "SAVE_STATE"
	CHECK_RA_AND_SAVE "MENU_TOGGLE"

	DISPLAY_WRITE disp0 setbl 0
	amixer set "Master" mute >/dev/null 2>&1

	cat "$CPU_GOV_PATH" >"$WAKE_CPU_GOV"

	if [ "$RGB_ENABLE" -eq 1 ] && [ "$LED_RGB" -eq 1 ]; then
		[ -f "$LED_CONTROL_SCRIPT" ] && "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
	fi

	case "$BOARD_NAME" in
		rg*) echo "0" >"$LED_NORMAL" ;;
	esac

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

	[ "$USB_FUNCTION" -ne 0 ] && /opt/muos/script/system/usb_gadget.sh resume

	amixer set "Master" unmute >/dev/null 2>&1
	CHECK_RA_AND_SAVE "MENU_TOGGLE"

	# Some stupid TrimUI GPU shenanigans
	case "$BOARD_NAME" in
		rg*) cat "$LED_STATE" >"$LED_NORMAL" ;;
		mgx* | tui*) setalpha 0 ;;
	esac

	cat "$WAKE_CPU_GOV" >"$CPU_GOV_PATH"
	rm -rf "$WAKE_CPU_GOV"

	if [ "$HAS_NETWORK" -eq 1 ]; then
		[ "$CONNECT_ON_WAKE" -eq 1 ] && nohup /opt/muos/script/system/network.sh connect >/dev/null 2>&1 &
	fi

	ACTIVITY_TRACKER start

	# Restart hotkey just in case something explodes
	HOTKEY restart

	# We're going to wait for the predefined grace period to stop sleep suspend from triggering again
	RECENT_WAKE_CLEAR_LATER
}

RECENT_WAKE_SET && exit 0

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
