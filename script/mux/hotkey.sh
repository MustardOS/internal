#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/mux/idle.sh

SLEEP_STATE_FILE=/tmp/sleep_state
POWER_LONG_FILE=/tmp/trigger/POWER_LONG

DPAD_FILE=/sys/class/power_supply/axp2202-battery/nds_pwrkey
HALL_KEY_FILE=/sys/class/power_supply/axp2202-battery/hallkey

RGBCONTROLLER_DIR="$(GET_VAR device storage/rom/mount)/MUOS/application/.rgbcontroller"

READ_HOTKEYS() {
	# Restart muhotkey if it exits. (tweak.sh kills it on config changes.)
	while :; do
		/opt/muos/extra/muhotkey /opt/muos/device/current/control/hotkey.json
	done
}

HANDLE_HOTKEY() {
	# This blocks the event loop, so commands here should finish quickly.
	case "$1" in
		# Input activity/idle:
		IDLE_ACTIVE) DISPLAY_ACTIVE ;;
		IDLE_DISPLAY) DISPLAY_IDLE ;;
		IDLE_SLEEP) SLEEP ;;

		# Power combos:
		OSF) /opt/muos/script/mux/quit.sh reboot osf ;;
		SLEEP) SLEEP ;;

		# Utility combos:
		SCREENSHOT) /opt/muos/script/mux/screenshot.sh ;;
		DPAD_TOGGLE) DPAD_TOGGLE ;;

		# Brightness/volume combos:
		BRIGHT_UP) /opt/muos/device/current/input/combo/bright.sh U ;;
		VOL_UP) /opt/muos/device/current/input/combo/audio.sh U ;;
		BRIGHT_DOWN) /opt/muos/device/current/input/combo/bright.sh D ;;
		VOL_DOWN) /opt/muos/device/current/input/combo/audio.sh D ;;

		# RGB combos:
		RGB_MODE) RGBCLI -m up ;;
		RGB_BRIGHT_UP) RGBCLI -b up ;;
		RGB_BRIGHT_DOWN) RGBCLI -b down ;;
		RGB_COLOR_PREV) RGBCLI -c down ;;
		RGB_COLOR_NEXT) RGBCLI -c up ;;

		# "RetroArch Network Wait" combos:
		RETROWAIT_IGNORE) [ "$(GET_VAR global settings/advanced/retrowait)" -eq 1 ] && echo ignore >/tmp/net_start ;;
		RETROWAIT_MENU) [ "$(GET_VAR global settings/advanced/retrowait)" -eq 1 ] && echo menu >/tmp/net_start ;;
	esac
}

LID_CLOSED() {
	case "$(GET_VAR device board/name)" in
		rg35xx-sp) [ "$(cat "$HALL_KEY_FILE")" -eq 0 ] ;;
		*) false ;;
	esac
}

SLEEP() {
	case "$(GET_VAR global settings/power/shutdown)" in
		# Disabled:
		-2) ;;
		# Sleep Suspend:
		-1)
			if [ "$(echo "$(UPTIME) - $(GET_VAR system resume_uptime) >= .1" | bc)" -eq 1 ]; then
				# When the user wakes the device from the mem
				# power state with a long press, we receive that
				# event right after resuming. Avoid suspending
				# again by ignoring power presses within 100ms.
				/opt/muos/script/system/suspend.sh power
			fi
			;;
		# Instant Shutdown:
		2) /opt/muos/script/mux/quit.sh poweroff sleep ;;
		# Sleep XXs + Shutdown:
		*)
			if [ ! -e "$POWER_LONG_FILE" ] || [ "$(cat "$POWER_LONG_FILE")" = off ]; then
				echo on >"$POWER_LONG_FILE"
			else
				echo off >"$POWER_LONG_FILE"
			fi
			;;
	esac
}

DPAD_TOGGLE() {
	if [ "$(GET_VAR global settings/advanced/dpad_swap)" -eq 1 ]; then
		RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"

		case "$(GET_VAR system foreground_process)" in
			mux*) ;;
			*)
				case "$(cat "$DPAD_FILE")" in
					0)
						echo 2 >"$DPAD_FILE"
						RUMBLE "$RUMBLE_DEVICE" .1
						;;
					2)
						echo 0 >"$DPAD_FILE"
						RUMBLE "$RUMBLE_DEVICE" .1
						sleep .1
						RUMBLE "$RUMBLE_DEVICE" .1
						;;
				esac
				;;
		esac
	fi
}

RGBCLI() {
	LD_LIBRARY_PATH="$RGBCONTROLLER_DIR/libs:$LD_LIBRARY_PATH" \
		"$RGBCONTROLLER_DIR/love" "$RGBCONTROLLER_DIR/rgbcli" "$@"
}

mkdir -p /tmp/trigger
echo awake >"$SLEEP_STATE_FILE"

# Start background power listener and sleep timer.
if [ "$(GET_VAR global boot/factory_reset)" -eq 0 ]; then
	/opt/muos/device/current/input/trigger/power.sh &
	/opt/muos/device/current/input/trigger/sleep.sh &
fi

READ_HOTKEYS | while read -r HOTKEY; do
	# Don't respond to any hotkeys while in charge mode or with lid closed.
	if [ "$(GET_VAR system foreground_process)" = muxcharge ] || LID_CLOSED; then
		continue
	fi

	# During soft sleep, only respond to the power button (to wake back up).
	if [ "$(cat "$SLEEP_STATE_FILE")" != awake ] && [ "$HOTKEY" != SLEEP ]; then
		continue
	fi

	HANDLE_HOTKEY "$HOTKEY"
done
