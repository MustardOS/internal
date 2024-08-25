#!/bin/sh

. /opt/muos/script/var/func.sh

BRIGHT_FILE="/opt/muos/config/brightness.txt"
BRIGHT_FILE_PERCENT="/tmp/current_brightness_percent"
SLEEP_STATE="/tmp/sleep_state"

CURRENT_BL=$(DISPLAY_READ lcd0 getbl)

SET_CURRENT() {
	C_BRIGHT=$1

	if [ "$C_BRIGHT" -eq 0 ]; then
		echo 4 >/sys/class/graphics/fb0/blank
		DISPLAY_WRITE lcd0 setbl "0"

		printf "%d" "$C_BRIGHT" >"$BRIGHT_FILE_PERCENT"

		SET_VAR "global" "settings/general/brightness" "0"

		if ! pgrep -f "muxcharge" >/dev/null; then
			printf "%d" "$C_BRIGHT" >"$BRIGHT_FILE"
			echo "Brightness set to $C_BRIGHT ($C_BRIGHT%)"
		fi
	else
		echo 0 >/sys/class/graphics/fb0/blank

		PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($C_BRIGHT/$(GET_VAR "device" "screen/bright"))*100}")
		printf "%d" "$PERCENTAGE" >"$BRIGHT_FILE_PERCENT"

		SET_VAR "global" "settings/general/brightness" "$((C_BRIGHT - 2))"
		DISPLAY_WRITE lcd0 setbl "$C_BRIGHT"

		if ! pgrep -f "muxcharge" >/dev/null; then
			printf "%d" "$C_BRIGHT" >"$BRIGHT_FILE"
			echo "Brightness set to $C_BRIGHT ($PERCENTAGE%)"
		fi
	fi
}

if [ -z "$1" ]; then
	PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($CURRENT_BL/$(GET_VAR "device" "screen/bright"))*100}")
	echo "Brightness is $CURRENT_BL ($PERCENTAGE%)"
	exit 0
fi

if [ ! "$(cat "$(GET_VAR "device" "screen/hdmi")")" = "HDMI=1" ] && [ "$(cat "$SLEEP_STATE")" = "awake" ]; then
	case "$1" in
		I)
			E_BRIGHT="$(cat $BRIGHT_FILE)"
			[ "$E_BRIGHT" -lt 1 ] && E_BRIGHT=90
			DISPLAY_WRITE lcd0 setbl "$E_BRIGHT"
			PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($E_BRIGHT/$(GET_VAR "device" "screen/bright"))*100}")
			echo "$PERCENTAGE" >/tmp/current_brightness_percent
			;;
		U)
			if [ "$CURRENT_BL" -le 14 ]; then
				NEW_BL=$((CURRENT_BL + 1))
			else
				NEW_BL=$((CURRENT_BL + 15))
			fi
			if [ "$NEW_BL" -gt "$(GET_VAR "device" "screen/bright")" ]; then
				NEW_BL=$(GET_VAR "device" "screen/bright")
			fi
			SET_CURRENT "$NEW_BL"
			;;
		D)
			if [ "$CURRENT_BL" -le 15 ]; then
				NEW_BL=$((CURRENT_BL - 1))
			else
				NEW_BL=$((CURRENT_BL - 15))
			fi
			if [ "$NEW_BL" -lt 0 ]; then
				NEW_BL=0
			fi
			SET_CURRENT "$NEW_BL"
			;;
		[0-9]*)
			if [ "$1" -ge 0 ] && [ "$1" -le "$(GET_VAR "device" "screen/bright")" ]; then
				SET_CURRENT "$1"
			else
				echo "Invalid brightness value. Maximum is $(GET_VAR "device" "screen/bright")."
			fi
			;;
		*)
			printf "Invalid Argument\n\tU) Increase Brightness\n\tD) Decrease Brightness\n"
			;;
	esac
fi
