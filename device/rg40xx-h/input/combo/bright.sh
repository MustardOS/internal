#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/screen.sh

BRIGHT_FILE="/opt/muos/config/brightness.txt"
BRIGHT_FILE_PERCENT="/tmp/current_brightness_percent"

SLEEP_STATE="/tmp/sleep_state"
SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")

GET_CURRENT() {
	DISPLAY_READ lcd0 getbl
}

CURRENT_BL=$(GET_CURRENT)

SET_CURRENT() {
	if [ $1 -eq 0 ]; then
		echo 4 >/sys/class/graphics/fb0/blank

		printf "%d" "$1" >"$BRIGHT_FILE_PERCENT"
		if ! pgrep -f "muxcharge" >/dev/null; then
			printf "%d" "$1" >"$BRIGHT_FILE"
			echo "Brightness set to $1 ($1%)"
		fi
	else
		echo 0 >/sys/class/graphics/fb0/blank

		PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($1/$DC_SCR_BRIGHT)*100}")
		printf "%d" "$PERCENTAGE" >"$BRIGHT_FILE_PERCENT"

		DISPLAY_WRITE lcd0 setbl "$1"

		if ! pgrep -f "muxcharge" >/dev/null; then
			printf "%d" "$1" >"$BRIGHT_FILE"
			echo "Brightness set to $1 ($PERCENTAGE%)"
		fi
	fi
}

if [ -z "$1" ]; then
	PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($CURRENT_BL/$DC_SCR_BRIGHT)*100}")
	echo "Brightness is $CURRENT_BL ($PERCENTAGE%)"
	exit 0
fi

if [ ! "$(cat "$DC_SCR_HDMI")" = "HDMI=1" ]; then
	case "$1" in
		I)
			PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($CURRENT_BL/$DC_SCR_BRIGHT)*100}")
			echo "$PERCENTAGE" >/tmp/current_brightness_percent
			;;
		U)
			if [ "$CURRENT_BL" -le 14 ]; then
				NEW_BL=$((CURRENT_BL + 1))
			else
				NEW_BL=$((CURRENT_BL + 15))
			fi
			if [ "$NEW_BL" -gt "$DC_SCR_BRIGHT" ]; then
				NEW_BL=$DC_SCR_BRIGHT
			fi
			SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
			if [ "$SLEEP_STATE_VAL" = "awake" ]; then
				SET_CURRENT "$NEW_BL"
			fi
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
			SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
			if [ "$SLEEP_STATE_VAL" = "awake" ]; then
				SET_CURRENT "$NEW_BL"
			fi
			;;
		[0-9]*)
			if [ "$1" -ge 0 ] && [ "$1" -le "$DC_SCR_BRIGHT" ]; then
				SET_CURRENT "$1"
			else
				echo "Invalid brightness value. Maximum is $DC_SCR_BRIGHT."
			fi
			;;
		*)
			printf "Invalid Argument\n\tU) Increase Brightness\n\tD) Decrease Brightness\n"
			;;
	esac
fi
