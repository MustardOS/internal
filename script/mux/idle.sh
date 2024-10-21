#!/bin/sh

. /opt/muos/script/var/func.sh

INHIBIT_NONE=0
INHIBIT_BOTH=1
INHIBIT_SLEEP=2

LED_CONTROL=/opt/muos/device/current/script/led_control.sh
RGBCONF=/run/muos/storage/theme/active/rgb/rgbconf.sh

DISPLAY_IDLE() {
	if [ "$(DISPLAY_READ lcd0 getbl)" -gt 10 ]; then
		DISPLAY_WRITE lcd0 setbl 10
	fi
	case "$(GET_VAR device board/name)" in
		rg40xx*) "$LED_CONTROL" 1 0 0 0 0 0 0 0 ;;
	esac
}

DISPLAY_ACTIVE() {
	BL="$(cat "$BRIGHT_FILE")"
	if [ "$(DISPLAY_READ lcd0 getbl)" -ne "$BL" ]; then
		DISPLAY_WRITE lcd0 setbl "$BL"
	fi
	case "$(GET_VAR device board/name)" in
		rg40xx*) [ -x "$RGBCONF" ] && "$RGBCONF" ;;
	esac
}

# Monitor for specific programs that should inhibit idle timeout.
while true; do
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
