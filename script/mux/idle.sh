#!/bin/sh

. /opt/muos/script/var/func.sh

IS_IDLE="/tmp/is_idle"

INHIBIT_NONE=0
INHIBIT_BOTH=1
INHIBIT_SLEEP=2

DO_BRIGHT=10
KEEP_BRIGHT=

DISPLAY_IDLE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ "1"

	BL="$(GET_VAR "config" "settings/general/brightness")"
	KEEP_BRIGHT=$BL

	[ "$BL" -gt "$DO_BRIGHT" ] && /opt/muos/device/script/bright.sh "$DO_BRIGHT"

	[ -f "$LED_CONTROL_SCRIPT" ] && "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0

	touch "$IS_IDLE"
}

DISPLAY_ACTIVE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ "0"

	BL="$(GET_VAR "config" "settings/general/brightness")"

	[ "$BL" -ne "$KEEP_BRIGHT" ] && /opt/muos/device/script/bright.sh "$KEEP_BRIGHT"

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
		[ "$CHARGING" -eq 1 ] && INHIBIT="$INHIBIT_SLEEP"
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
