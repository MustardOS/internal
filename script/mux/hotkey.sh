#!/bin/sh

. /opt/muos/script/var/func.sh

IS_NORMAL_MODE() {
	[ "$(GET_VAR "config" "boot/factory_reset")" -eq 0 ]
}

# Normal mode is from above stating that the factory reset routine is complete
# and the device can act as it's supposed to, seems like some users are "sleeping"
# their devices during the factory reset process.

# Handheld mode is a statement from the `func.sh` file stating whether or not
# the Console Mode (HDMI) is preset and active.  We don't want specific hotkeys
# to run if we are in Console Mode.

IS_NORMAL_MODE && IS_HANDHELD_MODE && . /opt/muos/script/mux/idle.sh

READ_HOTKEYS() {
	# Restart muhotkey if it exits. (tweak.sh kills it on config changes.)
	while :; do
		/opt/muos/frontend/muhotkey /opt/muos/device/control/hotkey.json
	done
}

HANDLE_HOTKEY() {
	# This blocks the event loop, so commands here should finish quickly.
	case "$1" in
		# Input activity/idle:
		IDLE_ACTIVE) IS_NORMAL_MODE && IS_HANDHELD_MODE && DISPLAY_ACTIVE ;;
		IDLE_DISPLAY) IS_NORMAL_MODE && IS_HANDHELD_MODE && DISPLAY_IDLE ;;
		IDLE_SLEEP) IS_NORMAL_MODE && IS_HANDHELD_MODE && SLEEP ;;

		# Power combos:
		OSF_R) IS_NORMAL_MODE && /opt/muos/script/mux/quit.sh reboot osf ;;
		OSF_S) IS_NORMAL_MODE && /opt/muos/script/mux/quit.sh poweroff osf ;;
		SLEEP) IS_NORMAL_MODE && SLEEP ;;

		# Utility combos:
		SCREENSHOT) IS_NORMAL_MODE && IS_HANDHELD_MODE && /opt/muos/script/mux/screenshot.sh ;;
		DPAD_TOGGLE) IS_NORMAL_MODE && DPAD_TOGGLE ;;

		# Brightness/volume combos:
		FIX_PANEL) IS_HANDHELD_MODE && /opt/muos/script/device/bright.sh F ;;
		BRIGHT_UP) IS_HANDHELD_MODE && /opt/muos/script/device/bright.sh U ;;
		BRIGHT_DOWN) IS_HANDHELD_MODE && /opt/muos/script/device/bright.sh D ;;
		VOL_UP) /opt/muos/script/device/audio.sh U ;;
		VOL_DOWN) /opt/muos/script/device/audio.sh D ;;

		# RGB combos:
		RGB_MODE) IS_NORMAL_MODE && IS_HANDHELD_MODE && RGBCLI -m up ;;
		RGB_BRIGHT_UP) IS_NORMAL_MODE && IS_HANDHELD_MODE && RGBCLI -b up ;;
		RGB_BRIGHT_DOWN) IS_NORMAL_MODE && IS_HANDHELD_MODE && RGBCLI -b down ;;
		RGB_COLOR_PREV) IS_NORMAL_MODE && IS_HANDHELD_MODE && RGBCLI -c down ;;
		RGB_COLOR_NEXT) IS_NORMAL_MODE && IS_HANDHELD_MODE && RGBCLI -c up ;;

		# "RetroArch Network Wait" combos:
		RETROWAIT_IGNORE) IS_NORMAL_MODE && [ "$(GET_VAR "config" "settings/advanced/retrowait")" -eq 1 ] && echo ignore >/tmp/net_start ;;
		RETROWAIT_MENU) IS_NORMAL_MODE && [ "$(GET_VAR "config" "settings/advanced/retrowait")" -eq 1 ] && echo menu >/tmp/net_start ;;
	esac
}

LID_CLOSED() {
	case "$(GET_VAR "device" "board/name")" in
		rg34xx-sp | rg35xx-sp)
			HALL_KEY_FILE="/sys/class/power_supply/axp2202-battery/hallkey"
			[ "$(cat "$HALL_KEY_FILE")" -eq 0 ]
			;;
		*) false ;;
	esac
}

SLEEP() {
	if IS_NORMAL_MODE; then
		CURR_UPTIME=$(UPTIME)
		if [ "$(echo "$CURR_UPTIME - $(GET_VAR "system" "resume_uptime") >= 1" | bc)" -eq 1 ]; then
			/opt/muos/script/system/suspend.sh &
			SET_VAR "system" "resume_uptime" "$CURR_UPTIME"
		fi
	fi
}

DPAD_TOGGLE() {
	RECENT_WAKE="/tmp/recent_wake"

	if [ ! -f "$RECENT_WAKE" ] && [ "$(GET_VAR "config" "settings/advanced/dpad_swap")" -eq 1 ]; then
		RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"

		case "$(GET_VAR "system" "foreground_process")" in
			mux*) ;;
			*)
				case "$(GET_VAR "device" "board/name")" in
					rg*)
						DPAD_FILE="/sys/class/power_supply/axp2202-battery/nds_pwrkey"
						case "$(cat "$DPAD_FILE")" in
							0)
								echo 2 >"$DPAD_FILE"
								RUMBLE "$RUMBLE_DEVICE" .1
								;;
							2)
								echo 0 >"$DPAD_FILE"
								RUMBLE "$RUMBLE_DEVICE" .1
								TBOX sleep 0.1
								RUMBLE "$RUMBLE_DEVICE" .1
								;;
						esac
						;;
					tui*)
						DPAD_FILE="/tmp/trimui_inputd/input_dpad_to_joystick"
						if [ -e "$DPAD_FILE" ]; then
							rm -f "$DPAD_FILE"
							RUMBLE "$RUMBLE_DEVICE" .1
						else
							touch "$DPAD_FILE"
							RUMBLE "$RUMBLE_DEVICE" .1
							TBOX sleep 0.1
							RUMBLE "$RUMBLE_DEVICE" .1
						fi
						;;
				esac
				;;
		esac
	fi
}

RGBCLI() {
	RGBCONTROLLER_DIR="$MUOS_SHARE_DIR/application/RGB Controller"

	LD_LIBRARY_PATH="$RGBCONTROLLER_DIR/libs:$LD_LIBRARY_PATH" \
		"$RGBCONTROLLER_DIR/love" "$RGBCONTROLLER_DIR/rgbcli" "$@"
}

READ_HOTKEYS | while read -r HOTKEY; do
	# Don't respond to any hotkeys while in charge mode or with lid closed.
	if pgrep "muxcharge" >/dev/null 2>&1 || LID_CLOSED; then
		continue
	fi

	HANDLE_HOTKEY "$HOTKEY"
done
