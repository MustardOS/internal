#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/audio.sh
. /opt/muos/script/var/device/screen.sh

VOLUME_FILE="/opt/muos/config/volume.txt"
VOLUME_FILE_PERCENT="/tmp/current_volume_percent"

SLEEP_STATE="/tmp/sleep_state"

GET_CURRENT() {
	amixer sget "$DC_SND_CONTROL" | sed -n "s/.*$DC_SND_CHANNEL: 0*\([0-9]*\).*/\1/p" | tr -d '\n'
}

CURRENT_VL=$(GET_CURRENT)

SET_CURRENT() {
	PERCENTAGE=$(awk "BEGIN {printf \"%d\", (($1 - $DC_SND_MIN) / ($DC_SND_MAX - $DC_SND_MIN)) * 100}")
	if [ "$PERCENTAGE" -lt 0 ]; then
		PERCENTAGE=0
	fi
	printf "%d" "$PERCENTAGE" >"$VOLUME_FILE_PERCENT"

	amixer sset "$DC_SND_CONTROL" $1 >/dev/null

	printf "%d" "$1" >"$VOLUME_FILE"
	echo "Volume set to $1 ($PERCENTAGE%)"
}

if [ -z "$1" ]; then
	PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($CURRENT_VL/$DC_SND_MAX)*100}")
	echo "Volume is $CURRENT_VL ($PERCENTAGE%)"
	exit 0
fi

if [ ! "$(cat "$DC_SCR_HDMI")" = "HDMI=1" ]; then
	case "$1" in
		I)
			PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($CURRENT_VL/$DC_SND_MAX)*100}")
			echo "$PERCENTAGE" >/tmp/current_volume_percent
			;;
		U)
			NEW_VL=$((CURRENT_VL + 2))
			if [ "$NEW_VL" -lt "$DC_SND_MIN" ]; then
				NEW_VL=$DC_SND_MIN
			fi
			if [ "$NEW_VL" -gt "$DC_SND_MAX" ]; then
				NEW_VL=$DC_SND_MAX
			fi
			SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
			if [ "$SLEEP_STATE_VAL" = "awake" ]; then
				SET_CURRENT "$NEW_VL"
			fi
			;;
		D)
			NEW_VL=$((CURRENT_VL - 2))
			if [ "$NEW_VL" -lt "$DC_SND_MIN" ]; then
				NEW_VL=0
			fi
			SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
			if [ "$SLEEP_STATE_VAL" = "awake" ]; then
				SET_CURRENT "$NEW_VL"
			fi
			;;
		[0-9]*)
			if [ "$1" -ge 0 ] && [ "$1" -le "$DC_SND_MAX" ]; then
				SET_CURRENT "$1"
			else
				printf "Invalid volume value\n\tMinimum is %s\n\tMaximum is %s\n" "$DC_SND_MAX" "$DC_SND_MAX"
			fi
			;;
		*)
			printf "Invalid Argument\n\tU) Increase Brightness\n\tD) Decrease Brightness\n"
			;;
	esac
fi
