#!/bin/sh

. /opt/muos/script/var/func.sh

INHIBIT_NONE=0
INHIBIT_BOTH=1
INHIBIT_SLEEP=2

BRIGHT_FILE=/opt/muos/config/brightness.txt

LED_CONTROL=/opt/muos/device/current/script/led_control.sh
RGBCONF=/run/muos/storage/theme/active/rgb/rgbconf.sh

DISPLAY_IDLE() {
	if [ "$(DISPLAY_READ lcd0 getbl)" -gt 10 ]; then
		DISPLAY_WRITE lcd0 setbl 10
	fi
	if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
		"$LED_CONTROL" 1 0 0 0 0 0 0 0
	fi
}

DISPLAY_ACTIVE() {
	BL="$(cat "$BRIGHT_FILE")"
	if [ "$(DISPLAY_READ lcd0 getbl)" -ne "$BL" ]; then
		DISPLAY_WRITE lcd0 setbl "$BL"
	fi
	if [ "$(GET_VAR device led/rgb)" -eq 1 ] && [ -x "$RGBCONF" ]; then
		"$RGBCONF"
	fi
}

# Monitor for specific programs that should inhibit idle timeout.
while :; do
	INHIBIT="$INHIBIT_NONE"
	# Inhibit idle sleep while charging.
	if [ "$(cat "$(GET_VAR device battery/charger)")" -eq 1 ]; then
		INHIBIT="$INHIBIT_SLEEP"
	fi
	# Inhibit idle display and sleep during long-running processes.
	case "$(GET_VAR system foreground_process)" in
		fbpad | ffplay | mpv | muxcharge | muxcredits | muxstart) INHIBIT="$INHIBIT_BOTH" ;;
	esac
	SET_VAR system idle_inhibit "$INHIBIT"
	sleep 5
done &
