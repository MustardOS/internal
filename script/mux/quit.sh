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
		/opt/muos/bin/toybox sleep .1
		kill -TERM "$FG_PROC_PID" 2>/dev/null

		for _ in $(seq 1 40); do
			if ! kill -KILL "$FG_PROC_PID" 2>/dev/null; then
				printf 'done\n'
				return
			fi
			/opt/muos/bin/toybox sleep .1
		done
	fi

	printf 'timed out\n'
}

# Blank screen to prevent visual glitches as running programs exit.
DISPLAY_BLANK() {
	touch "/tmp/mux_blank"
	DISPLAY_WRITE lcd0 setbl "0"
	echo 4 >/sys/class/graphics/fb0/blank
}

# Clears the last-played content so we won't relaunch it on the next boot.
CLEAR_LAST_PLAY() {
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

	{
		printf 'Halting system (command %s, source %s)\n' "$HALT_CMD" "$HALT_SRC"

		# Turn on power LED for visual feedback on halt success.
		echo 1 >"$(GET_VAR "device" "led/normal")"

		# Clear last-played content per Device Startup setting.
		#
		# Last Game: Always relaunch on boot.
		# Resume Game: Only relaunch on boot if we're running content
		# that was started via the launch script.
		case "$(GET_VAR "config" "settings/general/startup")" in
			last) ;;
			resume) pidof launch.sh >/dev/null || CLEAR_LAST_PLAY ;;
			*) CLEAR_LAST_PLAY ;;
		esac

		case "$HALT_SRC" in
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

		# Run syncthing scanner if enabled
		if [ "$(GET_VAR "config" "web/syncthing")" -eq 1 ] && [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ]; then
			SYNCTHING_API=$(cat /run/muos/storage/syncthing/config.xml | grep '<apikey>[^<]*</apikey>' | sed 's/.*<apikey>\([^<]*\)<\/apikey>.*/\1/')
			curl -X POST -H "X-API-Key: $SYNCTHING_API" "localhost:7070/rest/db/scan"
		fi
	} 2>&1 | ts '%Y-%m-%d %H:%M:%S' >>/opt/muos/halt.log

	exec /opt/muos/script/system/halt.sh "$HALT_CMD" >/dev/null 2>&1 &
}

[ "$#" -eq 2 ] || USAGE

case "$1" in
	close) CLOSE_CONTENT ;;
	poweroff | reboot) HALT_SYSTEM "$1" "$2" ;;
	*) USAGE ;;
esac
