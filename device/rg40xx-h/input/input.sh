#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/mux/close_game.sh

BRIGHT_FILE=/opt/muos/config/brightness.txt
SLEEP_STATE_FILE=/tmp/sleep_state
POWER_LONG_FILE=/tmp/trigger/POWER_LONG

RGBCONTROLLER_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.rgbcontroller"
RGBCONF_SCRIPT=/run/muos/storage/theme/active/rgb/rgbconf.sh

RESUME_UPTIME="$(UPTIME)"

READ_HOTKEYS() {
	# Restart muhotkey if it exits. (tweak.sh kills it on config changes.)
	# Order matters! Only the first matching combo will trigger.
	while true; do
		# Don't enable hold for RGB combos since rgbcli is a bit slow
		# and allowing holds makes the input loop unresponsive.
		/opt/muos/extra/muhotkey \
			-C OSF=POWER_LONG+L1+L2+R1+R2 \
			-C SLEEP=POWER_LONG \
			-C SCREENSHOT=POWER_SHORT+MENU_LONG \
			-H BRIGHT_UP=VOL_UP+MENU_LONG \
			-H VOL_UP=VOL_UP \
			-H BRIGHT_DOWN=VOL_DOWN+MENU_LONG \
			-H VOL_DOWN=VOL_DOWN \
			-C RGB_MODE=R3+MENU_LONG \
			-C RGB_BRIGHT_UP=RS_UP+MENU_LONG \
			-C RGB_BRIGHT_DOWN=RS_DOWN+MENU_LONG \
			-C RGB_COLOR_PREV=RS_LEFT+MENU_LONG \
			-C RGB_COLOR_NEXT=RS_RIGHT+MENU_LONG \
			-C RETROWAIT_IGNORE=START \
			-C RETROWAIT_MENU=SELECT
	done
}

HANDLE_HOTKEY() {
	# This blocks the event loop, so commands here should finish quickly.
	case "$1" in
		# Input activity/idle:
		IDLE_ACTIVE) DISPLAY_ACTIVE ;;
		IDLE_DISPLAY) DISPLAY_IDLE ;;
		IDLE_SLEEP) SLEEP ;;

		# Power long combos:
		OSF) HALT_SYSTEM osf reboot ;;
		SLEEP) SLEEP ;;

		# Power short combos:
		SCREENSHOT) /opt/muos/device/current/input/combo/screenshot.sh ;;

		# Volume combos:
		BRIGHT_UP) /opt/muos/device/current/input/combo/bright.sh U ;;
		VOL_UP) /opt/muos/device/current/input/combo/audio.sh U ;;
		BRIGHT_DOWN) /opt/muos/device/current/input/combo/bright.sh D ;;
		VOL_DOWN) /opt/muos/device/current/input/combo/audio.sh D ;;

		# Stick combos:
		RGB_MODE) RGB_CLI -m up ;;
		RGB_BRIGHT_UP) RGB_CLI -b up ;;
		RGB_BRIGHT_DOWN) RGB_CLI -b down ;;
		RGB_COLOR_PREV) RGB_CLI -c down ;;
		RGB_COLOR_NEXT) RGB_CLI -c up ;;

		# Misc combos:
		RETROWAIT_IGNORE) [ "$(GET_VAR global settings/advanced/retrowait)" -eq 1 ] && printf "ignore" >"/tmp/net_start" ;;
		RETROWAIT_MENU) [ "$(GET_VAR global settings/advanced/retrowait)" -eq 1 ] && printf "menu" >"/tmp/net_start" ;;
	esac
}

MONITOR_IDLE_INHIBIT() {
	# Monitor for specific programs that should inhibit idle timeout and
	# prevent us from dimming the display or going to sleep.
	while true; do
		case "$(GET_VAR system foreground_process)" in
			fbpad | muxcharge | muxcredits | muxstart) IDLE_INHIBIT=1 ;;
			*) IDLE_INHIBIT=0 ;;
		esac
		# evsieve grabs input devices for exclusive access, preventing muhotkey from detecting
		# activity. Disable idle entirely while it's running.
		if pgrep -x evsieve >/dev/null; then
			IDLE_INHIBIT=1
		fi
		SET_VAR system idle_inhibit "$IDLE_INHIBIT"
		sleep 5
	done
}

DISPLAY_IDLE() {
	if [ "$(DISPLAY_READ lcd0 getbl)" -gt 10 ]; then
		DISPLAY_WRITE lcd0 setbl 10
	fi
	/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
}

DISPLAY_ACTIVE() {
	BL="$(cat "$BRIGHT_FILE")"
	if [ "$(DISPLAY_READ lcd0 getbl)" -ne "$BL" ]; then
		DISPLAY_WRITE lcd0 setbl "$BL"
	fi
	[ -x "$RGBCONF_SCRIPT" ] && "$RGBCONF_SCRIPT"
}

SLEEP() {
	case "$(GET_VAR global settings/power/shutdown)" in
		# Disabled:
		-2) ;;
		# Sleep Suspend:
		-1)
			if [ "$(echo "$(UPTIME) - $RESUME_UPTIME >= .1" | bc)" -eq 1 ]; then
				# When the user wakes the device from the mem
				# power state with a long press, we receive that
				# event right after resuming. Avoid suspending
				# again by ignoring power presses within 100ms.
				/opt/muos/script/system/suspend.sh power
				RESUME_UPTIME="$(UPTIME)"
			fi
			;;
		# Instant Shutdown:
		2) HALT_SYSTEM sleep poweroff ;;
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

RGB_CLI() {
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

MONITOR_IDLE_INHIBIT &

READ_HOTKEYS | while read -r HOTKEY; do
	# Don't respond to any hotkeys while in charge mode.
	if [ "$(GET_VAR system foreground_process)" = muxcharge ]; then
		continue
	fi

	# During soft sleep, only respond to the power button (to wake back up).
	if [ "$(cat "$SLEEP_STATE_FILE")" != awake ] && [ "$HOTKEY" != SLEEP ]; then
		continue
	fi

	HANDLE_HOTKEY "$HOTKEY"
done
