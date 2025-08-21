#!/bin/sh

. /opt/muos/script/var/func.sh

# Lonely, oh so lonely...
RECENT_WAKE="/tmp/recent_wake"

HAS_NETWORK=$(GET_VAR "device" "board/network")
CPU_GOV_PATH="$(GET_VAR "device" "cpu/governor")"
CPU_CORES="$(GET_VAR "device" "cpu/cores")"
RGB_ENABLE=$(GET_VAR "config" "settings/general/rgb")
LED_RGB="$(GET_VAR "device" "led/rgb")"
RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"
RUMBLE_SETTING="$(GET_VAR "config" "settings/advanced/rumble")"
SUSPEND_STATE="$(GET_VAR "config" "danger/state")"
DEFAULT_BRIGHTNESS="$(GET_VAR "config" "settings/general/brightness")"
RTC_WAKE_PATH="$(GET_VAR "device" "board/rtc_wake")"
SHUTDOWN_TIME_SETTING="$(GET_VAR "config" "settings/power/shutdown")"

CHECK_RA_AND_SAVE() {
	# This is the safest bet to get RetroArch to save state automatically
	# if the user has configured their settings to do so...

	[ "$(GET_VAR "system" "foreground_process")" = "retroarch" ] && /usr/bin/retroarch --command "$1"

	# If you're reading this and thinking "WhAt AbOuT pOrTmAsTeR gAmEs?"
	# My answer is, you find out how to restore save game content and let us know!
}

SLEEP() {
	CHECK_RA_AND_SAVE "SAVE_STATE"
	CHECK_RA_AND_SAVE "MENU_TOGGLE"

	touch "$RECENT_WAKE"

	/opt/muos/device/script/bright.sh 0
	wpctl set-mute @DEFAULT_AUDIO_SINK@ "1"

	# Shutdown all of the CPU cores for boards that have actual proper
	# energy module within the kernel and device tree... unlike TrimUI
	case "$(GET_VAR "device" "board/name")" in
		rg*)
			cat "$CPU_GOV_PATH" >"/tmp/orig_cpu_gov"
			echo "powersave" >"$CPU_GOV_PATH"

			C=1
			while [ "$C" -lt "$CPU_CORES" ]; do
				echo 0 >"/sys/devices/system/cpu/cpu${C}/online"
				C=$((C + 1))
			done
			;;
		*) ;;
	esac

	if [ "$RGB_ENABLE" -eq 1 ] && [ "$LED_RGB" -eq 1 ]; then
		[ -f "$LED_CONTROL_SCRIPT" ] && "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
	fi

	case "$RUMBLE_SETTING" in
		3 | 5 | 6) RUMBLE "$RUMBLE_DEVICE" 0.3 ;;
	esac

	[ "$HAS_NETWORK" -eq 1 ] && /opt/muos/script/system/network.sh disconnect

	/opt/muos/device/script/module.sh unload

	echo "$SUSPEND_STATE" >/sys/power/state
}

RESUME() {
	case "$(GET_VAR "device" "board/name")" in
		rg*)
			cat "/tmp/orig_cpu_gov" >"$CPU_GOV_PATH"

			C=1
			while [ "$C" -lt "$CPU_CORES" ]; do
				echo 1 >"/sys/devices/system/cpu/cpu${C}/online"
				C=$((C + 1))
			done
			;;
		*) ;;
	esac

	/opt/muos/device/script/module.sh load &

	LED_CONTROL_CHANGE

	wpctl set-mute @DEFAULT_AUDIO_SINK@ "0"

	E_BRIGHT="$DEFAULT_BRIGHTNESS"

	# Some display panels don't like to resume on lower backlights due
	# to potential voltage lines or some shit... so let's resume on
	# a bit more brightness unfortunately!
	[ "$E_BRIGHT" -lt 11 ] && E_BRIGHT=40

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

		/opt/muos/device/script/bright.sh "$E_BRIGHT"
		B=$((B + 1))
	done

	CHECK_RA_AND_SAVE "MENU_TOGGLE"

	# We're going to wait for 5 seconds to stop sleep suspend from triggering again
	(
		/opt/muos/bin/toybox sleep 5
		rm "$RECENT_WAKE"
	) &

	[ "$HAS_NETWORK" -eq 1 ] && nohup /opt/muos/script/system/network.sh connect >/dev/null 2>&1 &
}

[ -f "$RECENT_WAKE" ] && exit 0

case "$SHUTDOWN_TIME_SETTING" in
	-2) ;;
	-1)
		SLEEP
		/opt/muos/bin/toybox sleep 0.5
		RESUME
		;;
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
		/opt/muos/bin/toybox sleep 0.5

		CURRENT_TIME=$(cat "$S_EPOCH")
		if [ "$CURRENT_TIME" -ge "$WAKE_EPOCH" ]; then
			/opt/muos/script/mux/quit.sh poweroff sleep
		else
			RESUME
		fi

		echo 0 >"$W_ALARM"
		;;
esac
