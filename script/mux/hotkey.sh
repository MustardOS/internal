#!/bin/sh

. /opt/muos/script/var/func.sh

if [ "$(GET_VAR "config" "boot/factory_reset")" -eq 0 ]; then
	IS_HANDHELD_MODE && . /opt/muos/script/mux/idle.sh
fi

DPAD_FILE=/sys/class/power_supply/axp2202-battery/nds_pwrkey
HALL_KEY_FILE=/sys/class/power_supply/axp2202-battery/hallkey

RGBCONTROLLER_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/RGB Controller"

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
		IDLE_ACTIVE) IS_HANDHELD_MODE && DISPLAY_ACTIVE ;;
		IDLE_DISPLAY) IS_HANDHELD_MODE && DISPLAY_IDLE ;;
		IDLE_SLEEP) IS_HANDHELD_MODE && SLEEP ;;

		# Power combos:
		OSF_R) /opt/muos/script/mux/quit.sh reboot osf ;;
		OSF_S) /opt/muos/script/mux/quit.sh poweroff osf ;;
		SLEEP) SLEEP ;;

		# Utility combos:
		SCREENSHOT) IS_HANDHELD_MODE && /opt/muos/script/mux/screenshot.sh ;;
		DPAD_TOGGLE) DPAD_TOGGLE ;;

		# Brightness/volume combos:
		FIX_PANEL) IS_HANDHELD_MODE && /opt/muos/device/script/bright.sh F ;;
		BRIGHT_UP) IS_HANDHELD_MODE && /opt/muos/device/script/bright.sh U ;;
		BRIGHT_DOWN) IS_HANDHELD_MODE && /opt/muos/device/script/bright.sh D ;;
		VOL_UP) /opt/muos/device/script/audio.sh U ;;
		VOL_DOWN) /opt/muos/device/script/audio.sh D ;;

		# RGB combos:
		RGB_MODE) RGBCLI -m up ;;
		RGB_BRIGHT_UP) RGBCLI -b up ;;
		RGB_BRIGHT_DOWN) RGBCLI -b down ;;
		RGB_COLOR_PREV) RGBCLI -c down ;;
		RGB_COLOR_NEXT) RGBCLI -c up ;;

		# "RetroArch Network Wait" combos:
		RETROWAIT_IGNORE) [ "$(GET_VAR "config" "settings/advanced/retrowait")" -eq 1 ] && echo ignore >/tmp/net_start ;;
		RETROWAIT_MENU) [ "$(GET_VAR "config" "settings/advanced/retrowait")" -eq 1 ] && echo menu >/tmp/net_start ;;
	esac
}

LID_CLOSED() {
	case "$(GET_VAR "device" "board/name")" in
		rg35xx-sp) [ "$(cat "$HALL_KEY_FILE")" -eq 0 ] ;;
		*) false ;;
	esac
}

SLEEP() {
	if [ "$(GET_VAR "config" "boot/factory_reset")" -eq 0 ]; then
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
				case "$(cat "$DPAD_FILE")" in
					0)
						echo 2 >"$DPAD_FILE"
						RUMBLE "$RUMBLE_DEVICE" .1
						;;
					2)
						echo 0 >"$DPAD_FILE"
						RUMBLE "$RUMBLE_DEVICE" .1
						/opt/muos/bin/toybox sleep .1
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

READ_HOTKEYS | while read -r HOTKEY; do
	# Don't respond to any hotkeys while in charge mode or with lid closed.
	if [ "$(GET_VAR "system" "foreground_process")" = "muxcharge" ] || LID_CLOSED; then
		continue
	fi

	HANDLE_HOTKEY "$HOTKEY"
done
