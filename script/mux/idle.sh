#!/bin/sh

. /opt/muos/script/var/func.sh

IS_IDLE="/tmp/is_idle"

INHIBIT_NONE=0
INHIBIT_BOTH=1
INHIBIT_SLEEP=2

DISPLAY_IDLE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ "1"

	[ "$(DISPLAY_READ lcd0 getbl)" -gt 10 ] && DISPLAY_WRITE lcd0 setbl 10

	[ -f "$LED_CONTROL_SCRIPT" ] && "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0

	touch "$IS_IDLE"
}

DISPLAY_ACTIVE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ "0"

	DISPLAY_WRITE lcd0 setbl "$(GET_VAR "config" "settings/general/brightness")"

	LED_CONTROL_CHANGE

	[ -e "$IS_IDLE" ] && rm -f "$IS_IDLE"
}

# Processes we need to look out for... just make sure to keep the space before and after!
WATCHLIST=" syncthing ffplay mpv muterm muxcharge muxbackup muxarchive muxcredits muxmessage "

while :; do
	INHIBIT="$INHIBIT_NONE"

	CHARGER_PATH="$(GET_VAR "device" "battery/charger")"
	if [ -r "$CHARGER_PATH" ]; then
		IFS= read -r CHARGING <"$CHARGER_PATH" || CHARGING=0
		if [ "$CHARGING" -eq 1 ]; then
			INHIBIT="$INHIBIT_SLEEP"
		else
			INHIBIT="$INHIBIT_NONE"
		fi
	fi

	# Have a peek at all of the running processes and break
	# if one is matched from our watch list
	for PROC in /proc/[0-9]*/comm; do
		[ -r "$PROC" ] || continue
		IFS= read -r P <"$PROC" || continue
		case "$WATCHLIST" in
			*" $P "*)
				INHIBIT="$INHIBIT_BOTH"
				break
				;;
		esac
	done

	SET_VAR "system" "idle_inhibit" "$INHIBIT"
	TBOX sleep 5
done &
