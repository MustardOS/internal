#!/bin/sh

. /opt/muos/script/var/func.sh

VOLUME_FILE="/opt/muos/config/volume.txt"
VOLUME_FILE_PERCENT="/tmp/current_volume_percent"

SLEEP_STATE="/tmp/sleep_state"
AUDIO_SRC="/tmp/mux_audio_src"

GET_CURRENT() {
	if [ "$(cat "$AUDIO_SRC")" = "pipewire" ]; then
		wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'
	else
		amixer sget "$(GET_VAR "device" "audio/control")" | sed -n "s/.*$(GET_VAR "device" "audio/channel"): 0*\([0-9]*\).*/\1/p" | tr -d '\n'
	fi
}

CURRENT_VL=$(GET_CURRENT)

SET_CURRENT() {
	PERCENTAGE=$(awk "BEGIN {printf \"%d\", (($1 - $(GET_VAR "device" "audio/min")) / ($(GET_VAR "device" "audio/max") - $(GET_VAR "device" "audio/min"))) * 100}")
	if [ "$PERCENTAGE" -lt 0 ]; then
		PERCENTAGE=0
	fi
	printf "%d" "$PERCENTAGE" >"$VOLUME_FILE_PERCENT"

	if [ "$(cat "$AUDIO_SRC")" = "pipewire" ]; then
		wpctl set-volume @DEFAULT_AUDIO_SINK@ $1% >/dev/null
	else
		amixer sset "$(GET_VAR "device" "audio/control")" $1 >/dev/null
	fi

	printf "%d" "$1" >"$VOLUME_FILE"
	echo "Volume set to $1 ($PERCENTAGE%)"
}

if [ -z "$1" ]; then
	PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($CURRENT_VL/$(GET_VAR "device" "audio/max"))*100}")
	echo "Volume is $CURRENT_VL ($PERCENTAGE%)"
	exit 0
fi

if [ ! "$(cat "$(GET_VAR "device" "screen/hdmi")")" = "HDMI=1" ] && [ "$(cat "$SLEEP_STATE")" = "awake" ]; then
	case "$1" in
		I)
			PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($CURRENT_VL/$(GET_VAR "device" "audio/max"))*100}")
			echo "$PERCENTAGE" >/tmp/current_volume_percent
			;;
		U)
			NEW_VL=$((CURRENT_VL + 8))
			if [ "$NEW_VL" -lt "$(GET_VAR "device" "audio/min")" ]; then
				NEW_VL=$(GET_VAR "device" "audio/min")
			fi
			if [ "$NEW_VL" -gt "$(GET_VAR "device" "audio/max")" ]; then
				NEW_VL=$(GET_VAR "device" "audio/max")
			fi
			SET_CURRENT "$NEW_VL"
			;;
		D)
			NEW_VL=$((CURRENT_VL - 8))
			if [ "$NEW_VL" -lt "$(GET_VAR "device" "audio/min")" ]; then
				NEW_VL=0
			fi
			SET_CURRENT "$NEW_VL"
			;;
		[0-9]*)
			if [ "$1" -ge 0 ] && [ "$1" -le "$(GET_VAR "device" "audio/max")" ]; then
				SET_CURRENT "$1"
			else
				printf "Invalid volume value\n\tMinimum is %s\n\tMaximum is %s\n" "$(GET_VAR "device" "audio/max")" "$(GET_VAR "device" "audio/max")"
			fi
			;;
		*)
			printf "Invalid Argument\n\tU) Increase Brightness\n\tD) Decrease Brightness\n"
			;;
	esac
fi
