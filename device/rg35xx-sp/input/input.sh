#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/mux/close_game.sh

BRIGHT_FILE=/opt/muos/config/brightness.txt
SLEEP_STATE_FILE=/tmp/sleep_state
POWER_LONG_FILE=/tmp/trigger/POWER_LONG
DPAD_FILE=/sys/class/power_supply/axp2202-battery/nds_pwrkey
HALL_KEY_FILE=/sys/class/power_supply/axp2202-battery/hallkey

RESUME_UPTIME="$(UPTIME)"

READ_HOTKEYS() {
	# Restart muhotkey if it exits. (tweak.sh kills it on config changes.)
	# Order matters! Only the first matching combo will trigger.
	while true; do
		/opt/muos/extra/muhotkey \
			-C OSF=POWER_LONG+L1+L2+R1+R2 \
			-C SLEEP=POWER_LONG \
			-C SCREENSHOT=POWER_SHORT+MENU_LONG \
			-C DPAD_TOGGLE=POWER_SHORT \
			-H BRIGHT_UP=VOL_UP+MENU_LONG \
			-H VOL_UP=VOL_UP \
			-H BRIGHT_DOWN=VOL_DOWN+MENU_LONG \
			-H VOL_DOWN=VOL_DOWN \
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
		DPAD_TOGGLE) DPAD_TOGGLE ;;

		# Volume combos:
		BRIGHT_UP) /opt/muos/device/current/input/combo/bright.sh U ;;
		VOL_UP) /opt/muos/device/current/input/combo/audio.sh U ;;
		BRIGHT_DOWN) /opt/muos/device/current/input/combo/bright.sh D ;;
		VOL_DOWN) /opt/muos/device/current/input/combo/audio.sh D ;;

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
		SET_VAR system idle_inhibit "$IDLE_INHIBIT"
		sleep 5
	done
}

DISPLAY_IDLE() {
	if [ "$(DISPLAY_READ lcd0 getbl)" -gt 10 ]; then
		DISPLAY_WRITE lcd0 setbl 10
	fi
}

DISPLAY_ACTIVE() {
	BL="$(cat "$BRIGHT_FILE")"
	if [ "$(DISPLAY_READ lcd0 getbl)" -ne "$BL" ]; then
		DISPLAY_WRITE lcd0 setbl "$BL"
	fi
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

DPAD_TOGGLE() {
	case "$(GET_VAR system foreground_process)" in
		mux*) ;;
		*)
			case "$(cat "$DPAD_FILE")" in
				0)
					echo 2 >"$DPAD_FILE"
					RUMBLE "$(GET_VAR device board/rumble)" .1
					;;
				2)
					echo 0 >"$DPAD_FILE"
					RUMBLE "$(GET_VAR device board/rumble)" .1
					sleep .1
					RUMBLE "$(GET_VAR device board/rumble)" .1
					;;
			esac
			;;
	esac
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
	# Don't respond to any hotkeys while in charge mode or with lid closed.
	if [ "$(GET_VAR system foreground_process)" = muxcharge ] || [ "$(cat "$HALL_KEY_FILE")" -eq 0 ]; then
		continue
	fi

	# During soft sleep, only respond to the power button (to wake back up).
	if [ "$(cat "$SLEEP_STATE_FILE")" != awake ] && [ "$HOTKEY" != SLEEP ]; then
		continue
	fi

	HANDLE_HOTKEY "$HOTKEY"
done
