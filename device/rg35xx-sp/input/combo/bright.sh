#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

MAX_BRIGHT=$(parse_ini "$DEVICE_CONFIG" "screen" "bright")

DISPLAY="/sys/kernel/debug/dispdbg"

BRIGHT_FILE="/opt/muos/config/brightness.txt"
BRIGHT_FILE_PERCENT="/tmp/current_brightness_percent"

SLEEP_STATE="/tmp/sleep_state"

GET_CURRENT() {
	echo getbl > $DISPLAY/command
	echo lcd0 > $DISPLAY/name
	echo 1 > $DISPLAY/start
	cat $DISPLAY/info
}

CURRENT_BL=$(GET_CURRENT)

SET_CURRENT() {
	if [ $1 -eq 0 ]; then
		echo disp0 > $DISPLAY/name
		echo suspend > $DISPLAY/command
		echo 1 > $DISPLAY/start;

		printf "%d" "$1" > "$BRIGHT_FILE_PERCENT"
  		if ! pgrep -f "muxcharge" > /dev/null
		then
			printf "%d" "$1" > "$BRIGHT_FILE"
   			echo "Brightness set to $1 ($1%)"
   		fi
	else
		echo disp0 > $DISPLAY/name
		echo resume > $DISPLAY/command
		echo 1 > $DISPLAY/start;

		PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($1/$MAX_BRIGHT)*100}")
		printf "%d" "$PERCENTAGE" > "$BRIGHT_FILE_PERCENT"

		echo lcd0 > $DISPLAY/name
		echo setbl > $DISPLAY/command
		echo "$1" > $DISPLAY/param
		echo 1 > $DISPLAY/start

		if ! pgrep -f "muxcharge" > /dev/null
		then
			printf "%d" "$1" > "$BRIGHT_FILE"
			echo "Brightness set to $1 ($PERCENTAGE%)"
		fi
	fi
}

if [ -z "$1" ]; then
	PERCENTAGE=$(awk "BEGIN {printf \"%d\", ($CURRENT_BL/$MAX_BRIGHT)*100}")
	echo "Brightness is $CURRENT_BL ($PERCENTAGE%)"
	exit 0
fi

case "$1" in
	U)
		if [ "$CURRENT_BL" -le 14 ]; then
			NEW_BL=$((CURRENT_BL + 1))
		else
			NEW_BL=$((CURRENT_BL + 15))
		fi
		if [ "$NEW_BL" -gt "$MAX_BRIGHT" ]; then
			NEW_BL=$MAX_BRIGHT
		fi
		SLEEP_STATE_VAL=$(cat "$SLEEP_STATE")
		if [ "$SLEEP_STATE_VAL" != "sleep-closed" ] || [ "$SLEEP_STATE_VAL" != "sleep-open" ]; then
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
		if [ "$SLEEP_STATE_VAL" != "sleep-closed" ] || [ "$SLEEP_STATE_VAL" != "sleep-open" ]; then
			SET_CURRENT "$NEW_BL"
		fi
		;;
	[0-9]*)
		if [ "$1" -ge 0 ] && [ "$1" -le "$MAX_BRIGHT" ]; then
			SET_CURRENT "$1"
		else
			echo "Invalid brightness value. Maximum is $MAX_BRIGHT."
		fi
		;;
	*)
		printf "Invalid Argument\n\tU) Increase Brightness\n\tD) Decrease Brightness\n"
		;;
esac

