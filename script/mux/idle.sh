#!/bin/sh

. /opt/muos/script/var/func.sh

INHIBIT_NONE=0
INHIBIT_BOTH=1
INHIBIT_SLEEP=2

DISPLAY_IDLE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ "1"

	if [ "$(DISPLAY_READ lcd0 getbl)" -gt 10 ]; then
		DISPLAY_WRITE lcd0 setbl 10
	fi

	[ -f "$LED_CONTROL_SCRIPT" ] && "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
}

DISPLAY_ACTIVE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ "0"

	BL="$(GET_VAR "config" "settings/general/brightness")"

	if [ "$(DISPLAY_READ lcd0 getbl)" -ne "$BL" ]; then
		DISPLAY_WRITE lcd0 setbl "$BL"
	fi

	LED_CONTROL_CHANGE
}

# Monitor for specific programs that should inhibit idle timeout.
while :; do
	INHIBIT="$INHIBIT_NONE"

	# Inhibit idle sleep while charging.
	if [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 1 ]; then
		INHIBIT="$INHIBIT_SLEEP"
	fi

	# Inhibit idle display and sleep during long-running processes.
	case "$(GET_VAR "system" "foreground_process")" in
		muterm | ffplay | mpv | muxcharge | muxcredits | muxmessage) INHIBIT="$INHIBIT_BOTH" ;;
	esac

	SET_VAR "system" "idle_inhibit" "$INHIBIT"
	/opt/muos/bin/toybox sleep 5
done &
