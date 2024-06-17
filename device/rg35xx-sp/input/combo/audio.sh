#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

AUDIO_CONTROL=$(parse_ini "$DEVICE_CONFIG" "audio" "control")
AUDIO_CHANNEL=$(parse_ini "$DEVICE_CONFIG" "audio" "channel")
AUDIO_VOL_MIN=$(parse_ini "$DEVICE_CONFIG" "audio" "min")
AUDIO_VOL_MAX=$(parse_ini "$DEVICE_CONFIG" "audio" "max")

VOLUME_FILE="/opt/muos/config/volume.txt"
VOLUME_FILE_PERCENT="/tmp/current_volume_percent"

SLEEP_STATE="/tmp/sleep_state"

GET_CURRENT() {
	amixer sget "$AUDIO_CONTROL" | sed -n "s/.*$AUDIO_CHANNEL: 0*\([0-9]*\).*/\1/p" | tr -d '\n'
}

CURRENT_VL=$(GET_CURRENT)

SET_CURRENT() {
	PERCENTAGE=$(awk "BEGIN {printf \"%d\", (($1 - $AUDIO_VOL_MIN) / ($AUDIO_VOL_MAX - $AUDIO_VOL_MIN)) * 100}")
	if [ "$PERCENTAGE" -lt 0 ]; then
		PERCENTAGE=0
	fi
	printf "%d" "$PERCENTAGE" > "$VOLUME_FILE_PERCENT"

	amixer sset "$AUDIO_CONTROL" $1 > /dev/null

	printf "%d" "$1" > "$VOLUME_FILE"
	echo "Volume set to $1 ($PERCENTAGE%)"
}

if [ -z "$1" ]; then
	PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($CURRENT_VL/$MAX_BRIGHT)*100}")
	echo "Volume is $CURRENT_VL ($PERCENTAGE%)"
	exit 0
fi

case "$1" in
	U)
		NEW_VL=$((CURRENT_VL + 2))
		if [ "$NEW_VL" -lt $AUDIO_VOL_MIN ]; then
			NEW_VL=$AUDIO_VOL_MIN
		fi
		if [ "$NEW_VL" -gt "$AUDIO_VOL_MAX" ]; then
			NEW_VL=$AUDIO_VOL_MAX
		fi
		SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
		if [ "$SLEEP_STATE_VAL" != "sleep-closed" ] || [ "$SLEEP_STATE_VAL" != "sleep-open" ]; then
			SET_CURRENT "$NEW_VL"
		fi
		;;
	D)
		NEW_VL=$((CURRENT_VL - 2))
		if [ "$NEW_VL" -lt $AUDIO_VOL_MIN ]; then
			NEW_VL=0
		fi
		SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
		if [ "$SLEEP_STATE_VAL" != "sleep-closed" ] || [ "$SLEEP_STATE_VAL" != "sleep-open" ]; then
			SET_CURRENT "$NEW_VL"
		fi
		;;
	[0-9]*)
		if [ "$1" -ge 0 ] && [ "$1" -le "$AUDIO_VOL_MAX" ]; then
			SET_CURRENT "$1"
		else
			printf "Invalid volume value\n\tMinimum is $AUDIO_VOL_MIN\n\tMaximum is $AUDIO_VOL_MAX\n"
		fi
		;;
	*)
		printf "Invalid Argument\n\tU) Increase Brightness\n\tD) Decrease Brightness\n"
		;;
esac

