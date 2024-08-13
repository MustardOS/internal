#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/device.sh

# Attempts to cleanly close the current foreground process, resuming it first
# if it's stopped. Waits five seconds before giving up.
CLOSE_CONTENT() {
	FG_PROC_VAL="$(cat /tmp/fg_proc)"
	FG_PROC_PID="$(pidof "$FG_PROC_VAL")"
	if [ -n "$FG_PROC_PID" ]; then
		kill -CONT "$FG_PROC_PID" 2>/dev/null
		kill "$FG_PROC_PID" 2>/dev/null
		for _ in $(seq 1 20); do
			if ! kill -0 "$FG_PROC_PID" 2>/dev/null; then
				break
			fi
			sleep .25
		done
	fi
}

# Cleanly halts, shuts down, or reboots the device.
#
# Usage: HALT_SYSTEM SRC CMD
#
# SRC allows specific based on how the halt was triggered. Current values are
# "frontend" (from launcher UI), "osf" (emergency reboot hotkey), and "sleep"
# (sleep timeout, possibly while playing content).
#
# CMD is one of "halt", "poweroff", or "reboot" and corresponds to the usual
# meaning of those programs.
HALT_SYSTEM () {
	. /opt/muos/script/var/global/setting_advanced.sh
	. /opt/muos/script/var/global/setting_general.sh
	. /opt/muos/script/var/global/storage.sh

	HALT_SRC="$1"
	HALT_CMD="$2"

	case "$HALT_CMD" in
		halt|poweroff) SPLASH_IMG=shutdown ;;
		reboot) SPLASH_IMG=reboot ;;
	esac

	# Turn on power LED for consistency across different halt codepaths.
	echo 1 >"$DC_DEV_LED"

	# Clear state we never want to persist across reboots.
	: >/opt/muos/config/address.txt

	case "$HALT_SRC" in
		frontend)
			# When not showing verbose output, display a
			# theme-provided splash screen during shutdown.
			if [ "$GC_ADV_VERBOSE" -eq 0 ]; then
				/opt/muos/extra/muxsplash "$GC_STO_THEME/MUOS/theme/active/image/$SPLASH_IMG.png"
			fi

			# Unless startup option is "last game", clear last
			# played so we don't rerun it on the next boot.
			if [ "$GC_GEN_STARTUP" != last ]; then
				: >/opt/muos/config/lastplay.txt
			fi
			;;
		osf)
			# Blank screen to prevent visual glitches during halt.
			DISPLAY_WRITE disp0 blank 1

			# Always clear last played on emergency halt in case
			# the content itself is what forced the user to reboot.
			: >/opt/muos/config/lastplay.txt
			;;
		sleep)
			# Blank screen to prevent visual glitches during halt.
			DISPLAY_WRITE disp0 blank 1

			# Close foreground process (for autosave, etc.).
			CLOSE_CONTENT

			# Only support "last game" and "resume game" startup
			# options for RetroArch; clear last played otherwise.
			if [ "$FG_PROC_VAL" != retroarch ]; then
				: >/opt/muos/config/lastplay.txt
			fi
			;;
	esac

	# When "verbose messages" setting is enabled, run the underlying halt
	# script in fbpad so its output is visible on screen.
	if [ "$GC_ADV_VERBOSE" -eq 1 ]; then
		/opt/muos/bin/fbpad /opt/muos/script/system/halt.sh "$HALT_CMD" </dev/null
	else
		/opt/muos/script/system/halt.sh "$HALT_CMD"
	fi
}
