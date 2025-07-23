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

SLEEP() {
	touch "$RECENT_WAKE"

	DISPLAY_WRITE lcd0 setbl "0"
	wpctl set-mute @DEFAULT_AUDIO_SINK@ "1"
	echo 4 >"/sys/class/graphics/fb0/blank"
	touch "/tmp/mux_blank"

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
		LED_CONTROL_SCRIPT="/opt/muos/device/script/led_control.sh"
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

	/opt/muos/device/script/module.sh load

	LED_CONTROL_CHANGE

	rm -f "/tmp/mux_blank"
	echo 0 >"/sys/class/graphics/fb0/blank"
	wpctl set-mute @DEFAULT_AUDIO_SINK@ "0"

	E_BRIGHT="$DEFAULT_BRIGHTNESS"
	[ "$E_BRIGHT" -lt 1 ] && E_BRIGHT=90
	DISPLAY_WRITE lcd0 setbl "$E_BRIGHT"

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
	2) /opt/muos/script/mux/quit.sh poweroff sleep ;;
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
