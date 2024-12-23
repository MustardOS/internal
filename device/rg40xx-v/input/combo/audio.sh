#!/bin/sh

. /opt/muos/script/var/func.sh

VOLUME_FILE="/opt/muos/config/volume.txt"
VOLUME_FILE_PERCENT="/tmp/current_volume_percent"
SLEEP_STATE="/tmp/sleep_state"

GET_CURRENT() {
	wpctl get-volume "$(GET_VAR "audio" "nid_internal")" |
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

	XDG_RUNTIME_DIR="/var/run" wpctl set-volume "$(GET_VAR "audio" "nid_internal")" "$PERCENTAGE%"

	printf "%s" "$PERCENTAGE" >"$VOLUME_FILE_PERCENT"
	printf "%s" "$VALUE" >"$VOLUME_FILE"
	printf "Volume set to %s (%s%%)\n" "$VALUE" "$PERCENTAGE"
}

if [ -z "$1" ]; then
	CURRENT_VL=$(GET_CURRENT)
	MAX=$(GET_VAR "device" "audio/max")
	PERCENTAGE=$((CURRENT_VL * 100 / MAX))
	printf "Volume is %s (%s%%)\n" "$CURRENT_VL" "$PERCENTAGE"
	exit 0
fi

if [ "$(cat "$SLEEP_STATE")" = "awake" ]; then
	MIN=$(GET_VAR "device" "audio/min")
	MAX=$(GET_VAR "device" "audio/max")

	case "$1" in
		I)
			CURRENT_VL=$(GET_CURRENT)
			PERCENTAGE=$((CURRENT_VL * 100 / MAX))
			printf "%s" "$PERCENTAGE" >"$VOLUME_FILE_PERCENT"
			;;
		U)
			CURRENT_VL=$(GET_CURRENT)
			NEW_VL=$((CURRENT_VL + 8))
			[ "$NEW_VL" -gt "$MAX" ] && NEW_VL=$MAX
			SET_CURRENT "$NEW_VL"
			;;
		D)
			CURRENT_VL=$(GET_CURRENT)
			NEW_VL=$((CURRENT_VL - 8))
			[ "$NEW_VL" -lt "$MIN" ] && NEW_VL=$MIN
			SET_CURRENT "$NEW_VL"
			;;
		[0-9]*)
			if [ "$1" -ge "$MIN" ] && [ "$1" -le "$MAX" ]; then
				SET_CURRENT "$1"
			else
				printf "Invalid volume value\n\tMinimum is %s\n\tMaximum is %s\n" "$MIN" "$MAX"
			fi
			;;
		*)
			printf "Invalid Argument\n\tU) Increase Volume\n\tD) Decrease Volume\n"
			;;
	esac
fi
