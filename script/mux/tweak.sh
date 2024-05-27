#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

COLOUR=$(parse_ini "$CONFIG" "settings.general" "colour")
echo "$COLOUR" > /sys/class/disp/disp/attr/color_temperature

HDMI=$(parse_ini "$CONFIG" "settings.general" "hdmi")
if [ "$HDMI" -eq 1 ]; then
	if ! pgrep -f "hdmi.sh" > /dev/null; then
		/opt/muos/script/system/hdmi.sh &
	fi
else
	if pgrep -f "hdmi.sh" > /dev/null; then
		DISPLAY="/sys/kernel/debug/dispdbg"
		killall hdmi.sh

		# Blank the screen
		echo disp0 > $DISPLAY/name
		echo blank > $DISPLAY/command
		echo 1 > $DISPLAY/param
		echo 1 > $DISPLAY/start;

		# Switch off HDMI
		echo disp0 > $DISPLAY/name
		echo switch > $DISPLAY/command
		echo 1 0 > $DISPLAY/param
		echo 1 > $DISPLAY/start

		# Reset the display
		fbset -g 1280 720 1280 1440 32
		fbset -g 640 480 640 960 32
		fbset -g 1280 720 1280 1440 32
		fbset -g 640 480 640 960 32

		# Unblank the screen
		echo disp0 > $DISPLAY/name
		echo blank > $DISPLAY/command
		echo 0 > $DISPLAY/param
		echo 1 > $DISPLAY/start;
	fi
fi

