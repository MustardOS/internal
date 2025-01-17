#!/bin/sh

. /opt/muos/script/var/func.sh

USAGE() {
	printf 'Usage: %s close|poweroff|reboot frontend|osf|sleep\n' "$0" >&2
	exit 1
}

# Attempts to cleanly close the current foreground process, resuming it first
# if it's stopped. Waits ten seconds before giving up.
CLOSE_CONTENT() {
	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
	FG_PROC_PID="$(pidof "$FG_PROC_VAL")"

	if [ -n "$FG_PROC_PID" ]; then
		printf 'Closing content (%s): ' "$FG_PROC_VAL"

		kill -CONT "$FG_PROC_PID" 2>/dev/null
		# HACK: Let content run for 10ms before SIGTERM to avoid a hang
		# in RetroArch alsathread driver (due to audio buffer underrun).
		sleep .01
		kill "$FG_PROC_PID" 2>/dev/null

		for _ in $(seq 1 40); do
			if ! kill -0 "$FG_PROC_PID" 2>/dev/null; then
				printf 'done\n'
				return
			fi
			sleep .25
		done
	fi

	printf 'timed out\n'
}

# Blank screen to prevent visual glitches as running programs exit.
DISPLAY_BLANK() {
	echo 4 >/sys/class/graphics/fb0/blank
	DISPLAY_WRITE disp0 setbl 0
}

# Clears the last-played content so we won't relaunch it on the next boot.
CLEAR_LAST_PLAY() {
	: >/opt/muos/config/lastplay.txt
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

	{
		printf 'Halting system (command %s, source %s)\n' "$HALT_CMD" "$HALT_SRC"

		case "$HALT_CMD" in
			poweroff) SPLASH_IMG=shutdown ;;
			reboot) SPLASH_IMG=reboot ;;
		esac

		# Turn on power LED for visual feedback on halt success.
		echo 1 >"$(GET_VAR "device" "led/normal")"

		# Clear state we never want to persist across reboots.
		: >/opt/muos/config/address.txt

		# Clear last-played content per Device Startup setting.
		#
		# Last Game: Always relaunch on boot.
		# Resume Game: Only relaunch on boot if we're running content
		# that was started via the launch script.
		case "$(GET_VAR "global" "settings/general/startup")" in
			last) ;;
			resume) pidof launch.sh >/dev/null || CLEAR_LAST_PLAY ;;
			*) CLEAR_LAST_PLAY ;;
		esac

		case "$HALT_SRC" in
			frontend)
				# When not showing verbose output, display a
				# theme-provided splash screen during shutdown.
				if [ "$(GET_VAR "global" "settings/advanced/verbose")" -eq 0 ]; then
					for path in \
						"/run/muos/storage/theme/active/$(GET_VAR device mux/width)x$(GET_VAR device mux/height)/image/$(GET_VAR global settings/general/language)/$SPLASH_IMG.png" \
						"/run/muos/storage/theme/active/$(GET_VAR device mux/width)x$(GET_VAR device mux/height)/image/$SPLASH_IMG.png" \
						"/run/muos/storage/theme/active/image/$(GET_VAR global settings/general/language)/$SPLASH_IMG.png" \
						"/run/muos/storage/theme/active/image/$SPLASH_IMG.png"
					do
						if [ -f "$path" ]; then
							SPLASH_IMG_PATH="$path"
							break
						fi
					done
					/opt/muos/extra/muxsplash "$SPLASH_IMG_PATH"
				fi
				;;
			osf)
				# Never relaunch content after failsafe reboot
				# since it may have been what hung or crashed.
				DISPLAY_BLANK
				CLEAR_LAST_PLAY
				;;
			sleep)
				DISPLAY_BLANK
				CLOSE_CONTENT
				;;
		esac
	} 2>&1 | ts '%Y-%m-%d %H:%M:%S' >>/opt/muos/halt.log

	if [ "$HALT_SRC" = frontend ] && [ "$(GET_VAR "global" "settings/advanced/verbose")" -eq 1 ]; then
		# When "verbose messages" setting is enabled, run the underlying
		# halt script in fbpad so its output is visible on screen.
		#
		# Fork into a new session to avoid fbpad getting killed early.
		# Redirect input so it doesn't get dumped onto fbpad's TTY.
		exec setsid -fw /opt/muos/bin/fbpad /opt/muos/script/system/halt.sh "$HALT_CMD" </dev/null
	else
		# Redirect output so it doesn't draw over the splash screen if
		# we're currently running inside a terminal.
		exec /opt/muos/script/system/halt.sh "$HALT_CMD" >/dev/null 2>&1
	fi
}

[ "$#" -eq 2 ] || USAGE

case "$1" in
	close) CLOSE_CONTENT ;;
	poweroff | reboot) HALT_SYSTEM "$1" "$2" ;;
	*) USAGE ;;
esac
