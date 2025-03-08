#!/bin/sh

. /opt/muos/script/var/func.sh

BRIGHT_FILE="/opt/muos/config/brightness.txt"
RECENT_WAKE="/tmp/recent_wake"

SLEEP() {
	DISPLAY_WRITE lcd0 setbl "0"
	wpctl set-mute @DEFAULT_AUDIO_SINK@ "1"
	echo 4 >/sys/class/graphics/fb0/blank
	touch "/tmp/mux_blank"

	CPU_GOV="$(cat "$(GET_VAR "device" "cpu/governor")")"
	echo "$CPU_GOV" >/tmp/orig_cpu_gov
	echo "powersave" >"$CPU_GOV"

	CORES="$(GET_VAR "device" "cpu/cores")"
	C=1
	while [ "$C" -lt "$CORES" ]; do
		echo 0 >"/sys/devices/system/cpu/cpu${C}/online"
		C=$((C + 1))
	done

	if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
		/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
	fi

	case "$(GET_VAR "global" "settings/advanced/rumble")" in
		3 | 5 | 6) RUMBLE "$(GET_VAR "device" "board/rumble")" 0.3 ;;
		*) ;;
	esac

	# We're going in, hold on to your horses!
	GET_VAR "global" "settings/advanced/state" >"/sys/power/state"

	# We're going to wait for 5 seconds to stop sleep suspend from triggering again
	(
		touch "$RECENT_WAKE"
		sleep 5
		rm "$RECENT_WAKE"
	) &
}

RESUME() {
	CPU_GOV="$(GET_VAR "device" "cpu/governor")"
	cat "/tmp/orig_cpu_gov" >"$CPU_GOV"

	CORES="$(GET_VAR "device" "cpu/cores")"
	C=1
	while [ "$C" -lt "$CORES" ]; do
		echo 1 >"/sys/devices/system/cpu/cpu${C}/online"
		C=$((C + 1))
	done

	if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
		RGBCONF_SCRIPT="/run/muos/storage/theme/active/rgb/rgbconf.sh"
		if [ -x "$RGBCONF_SCRIPT" ]; then
			"$RGBCONF_SCRIPT"
		else
			/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
		fi
	fi

	rm -f "/tmp/mux_blank"
	echo 0 >/sys/class/graphics/fb0/blank
	wpctl set-mute @DEFAULT_AUDIO_SINK@ "0"

	E_BRIGHT="$(cat "$BRIGHT_FILE")"
	[ "$E_BRIGHT" -lt 1 ] && E_BRIGHT=90
	DISPLAY_WRITE lcd0 setbl "$E_BRIGHT"
}

[ -f "$RECENT_WAKE" ] && exit 0

SHUTDOWN_TIME="$(GET_VAR "global" "settings/power/shutdown")"
case "$SHUTDOWN_TIME" in
	-2) ;;
	-1)
		SLEEP
		RESUME
		;;
	2) /opt/muos/script/mux/quit.sh poweroff sleep ;;
	*)
		CURRENT_EPOCH=$(cat "$(GET_VAR "device" "board/rtc_wake")"/since_epoch)
		SHUTDOWN_TIME=$((CURRENT_EPOCH + SHUTDOWN_TIME))
		echo "$SHUTDOWN_TIME" >"$(GET_VAR "device" "board/rtc_wake")"/wakealarm

		SLEEP

		CURRENT_TIME=$(cat "$(GET_VAR "device" "board/rtc_wake")"/since_epoch)
		if [ "$CURRENT_TIME" -ge "$SHUTDOWN_TIME" ]; then
			DISPLAY_WRITE lcd0 setbl "0"
			echo 4 >/sys/class/graphics/fb0/blank
			/opt/muos/script/mux/quit.sh poweroff sleep
		else
			RESUME
		fi

		echo 0 >"$(GET_VAR "device" "board/rtc_wake")"/wakealarm
		;;
esac
