#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE_MODE=$(GET_VAR "config" "boot/device_mode")
{ [ -z "$1" ] || [ "$DEVICE_MODE" -ne 0 ]; } && exit 0

MIN=$(GET_VAR "device" "audio/min")
MAX=$(GET_VAR "device" "audio/max")
INC=$(GET_VAR "config" "settings/advanced/incvolume")

GET_CURRENT() {
	wpctl get-volume @DEFAULT_AUDIO_SINK@ |
		awk '{for (i=1; i<=NF; i++) if ($i ~ /^[0-9.]+$/) print int($i * 100)}'
}

SET_CURRENT() {
	MIN=$(GET_VAR "device" "audio/min")
	MAX=$(GET_VAR "device" "audio/max")

	VALUE="$1"

	[ "$VALUE" -lt "$MIN" ] && VALUE="$MIN"
	[ "$VALUE" -gt "$MAX" ] && VALUE="$MAX"

	# Fuck you percentages!
	PERCENTAGE=$(((VALUE - MIN) * MAX / (MAX - MIN)))
	[ "$PERCENTAGE" -lt 0 ] && PERCENTAGE=0
	[ "$PERCENTAGE" -gt "$MAX" ] && PERCENTAGE="$MAX"

	wpctl set-volume @DEFAULT_AUDIO_SINK@ "$PERCENTAGE%"
	SET_VAR "config" "settings/general/volume" "$VALUE"
}

case "$1" in
	U)
		NEW_VL=$(($(GET_CURRENT) + INC))
		[ "$NEW_VL" -gt "$MAX" ] && NEW_VL=$MAX
		SET_CURRENT "$NEW_VL"
		;;
	D)
		NEW_VL=$(($(GET_CURRENT) - INC))
		[ "$NEW_VL" -lt "$MIN" ] && NEW_VL=$MIN
		SET_CURRENT "$NEW_VL"
		;;
	[0-9]*)
		[ "$1" -eq "$1" ] 2>/dev/null && [ "$1" -ge "$MIN" ] && [ "$1" -le "$MAX" ] && SET_CURRENT "$1"
		;;
	*) ;;
esac
