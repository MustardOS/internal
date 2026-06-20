#!/bin/sh

. /opt/muos/script/var/func.sh

USAGE() {
	printf 'Usage: %s close|poweroff|reboot frontend|osf|sleep [wait]\n' "$0" >&2
	exit 1
}

# Attempts to cleanly close the current foreground process, resuming it first
# if it's stopped. Sends SIGTERM and waits TERM_GRACE_SEC before escalating
# to SIGKILL, then waits up to KILL_WAIT_SEC for the process to actually exit.

TERM_GRACE_SEC=3
KILL_WAIT_SEC=7

WAIT_ACTION() {
	[ "$WAIT_SEC" -gt 0 ] || return 0

	LOG_INFO "$0" 0 "QUIT" "$(printf "Waiting %s second(s)..." "$WAIT_SEC")"
	sleep "$WAIT_SEC"
}

CLOSE_CONTENT() {
	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
	[ -z "$FG_PROC_VAL" ] && return 0

	FG_PROC_PID="$(pidof "$FG_PROC_VAL" 2>/dev/null)"
	[ -z "$FG_PROC_PID" ] && return 0

	LOG_INFO "$0" 0 "QUIT" "$(printf "Closing content (%s)..." "$FG_PROC_VAL")"

	# Resume the process in case it is suspended, then ask it to exit cleanly.
	kill -CONT "$FG_PROC_PID" 2>/dev/null
	sleep 0.1
	kill -TERM "$FG_PROC_PID" 2>/dev/null

	# Wait for TERM to take effect before escalating.
	_I=0
	while [ "$_I" -lt "$((TERM_GRACE_SEC * 10))" ]; do
		kill -0 "$FG_PROC_PID" 2>/dev/null || {
			LOG_INFO "$0" 0 "QUIT" "$(printf "Exited cleanly (%s)" "$FG_PROC_VAL")"
			return 0
		}
		sleep 0.1
		_I=$((_I + 1))
	done

	# Process did not respond to SIGTERM - escalate to SIGKILL.
	LOG_INFO "$0" 0 "QUIT" "$(printf "Escalating to SIGKILL (%s)..." "$FG_PROC_VAL")"

	_I=0
	while [ "$_I" -lt "$((KILL_WAIT_SEC * 10))" ]; do
		kill -0 "$FG_PROC_PID" 2>/dev/null || {
			LOG_INFO "$0" 0 "QUIT" "$(printf "Killed (%s)" "$FG_PROC_VAL")"
			return 0
		}
		kill -KILL "$FG_PROC_PID" 2>/dev/null
		sleep 0.1
		_I=$((_I + 1))
	done

	LOG_INFO "$0" 0 "QUIT" "$(printf "Process did not die (%s)" "$FG_PROC_VAL")"

}

# Blank screen to prevent visual glitches as running programs exit.
DISPLAY_BLANK() {
	LOG_INFO "$0" 0 "QUIT" "Blanking internal display"
	touch "/tmp/mux_blank"
	DISPLAY_WRITE disp0 setbl "0"
	echo 4 >/sys/class/graphics/fb0/blank
}

# Clears the last-played content so we won't relaunch it on the next boot.
CLEAR_LAST_PLAY() {
	LOG_INFO "$0" 0 "QUIT" "Clearing last played content"
	: >/opt/muos/config/boot/last_play
}

# Cleanly halts, shuts down, or reboots the device.
#
# Usage: HALT_SYSTEM CMD SRC
#
# CMD is "poweroff" or "reboot".
#
# SRC specifies how the halt was triggered. Current values are "frontend" (from
# launcher UI), "osf" (emergency reboot hotkey), and "sleep" (sleep timeout).
HALT_SYSTEM() {
	HALT_CMD="$1"
	HALT_SRC="$2"

	LED_CONTROL_CHANGE off

	LOG_INFO "$0" 0 "QUIT" "$(printf "Quitting system (cmd: %s) (src: %s)" "$HALT_CMD" "$HALT_SRC")"

	# Turn on power LED for visual feedback on halt success.
	LOG_INFO "$0" 0 "QUIT" "Switching on normal LED"
	echo 1 >"$(GET_VAR "device" "led/normal")"

	# Clear last-played content per Device Startup setting.
	#
	# Last Game: Always relaunch on boot.
	# Resume Game: Only relaunch on boot if we're running content
	# that was started via the launch script.
	case "$(GET_VAR "config" "settings/general/startup")" in
		last) ;;
		resume) pgrep -f "launch.sh" >/dev/null 2>&1 || CLEAR_LAST_PLAY ;;
		*) CLEAR_LAST_PLAY ;;
	esac

	LOG_INFO "$0" 0 "QUIT" "Detect if 'osf' or 'sleep' was triggered"
	case "$HALT_SRC" in
		osf)
			DISPLAY_BLANK
			CLEAR_LAST_PLAY
			;;
		sleep)
			DISPLAY_BLANK
			CLOSE_CONTENT
			;;
	esac

	# Avoid hangups from syncthing if it's running.
	TERMINATE_SYNCTHING
}

[ "$#" -eq 2 ] || [ "$#" -eq 3 ] || USAGE

WAIT_SEC="${3:-0}"
case "$WAIT_SEC" in
	'' | *[!0123456789]*) USAGE ;;
esac

case "$1" in
	close)
		WAIT_ACTION
		LOG_INFO "$0" 0 "QUIT" "Closing content..."
		CLOSE_CONTENT
		;;
	poweroff | reboot)
		WAIT_ACTION
		[ -f "/tmp/btl_go" ] && UPDATE_BOOTLOGO
		HALT_SYSTEM "$1" "$2"
		sync && /opt/muos/script/system/halt.sh "$1"
		;;
	*) USAGE ;;
esac
