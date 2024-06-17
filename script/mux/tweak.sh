#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

DISPLAY="/sys/kernel/debug/dispdbg"

FG_PROC="/tmp/fg_proc"

COLOUR=$(parse_ini "$CONFIG" "settings.general" "colour")
echo "$COLOUR" > /sys/class/disp/disp/attr/color_temperature

HDMI=$(parse_ini "$CONFIG" "settings.general" "hdmi")
if [ "$HDMI" -eq 1 ]; then
	if ! pgrep -f "hdmi.sh" > /dev/null; then
		SUPPORT_HDMI=$(parse_ini "$DEVICE_CONFIG" "device" "hdmi")
		if [ "$SUPPORT_HDMI" -eq 1 ]; then
			/opt/muos/device/"$DEVICE"/script/hdmi.sh &
		fi
	fi
else
	if pgrep -f "hdmi.sh" > /dev/null; then
		killall hdmi.sh

		# Blank the screen
		echo disp0 > $DISPLAY/name
		echo blank > $DISPLAY/command
		echo 1 > $DISPLAY/param
		echo 1 > $DISPLAY/start

		# Switch off HDMI
		echo disp0 > $DISPLAY/name
		echo switch > $DISPLAY/command
		echo 1 0 > $DISPLAY/param
		echo 1 > $DISPLAY/start

		FG_PROC_VAL=$(cat "$FG_PROC")

		if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" > /dev/null; then
			pkill -STOP "playbgm.sh"
			killall -q "mp3play"
		fi

		sed -i -E 's/(defaults\.(ctl|pcm)\.card) 0/\1 2/g' /usr/share/alsa/alsa.conf
		alsactl kill quit

		if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" > /dev/null; then
			pkill -CONT "playbgm.sh"
		fi

		# Reset the display
		fbset -g 1280 720 1280 1440 32
		fbset -g 640 480 640 960 32
		fbset -g 1280 720 1280 1440 32
		fbset -g 640 480 640 960 32

		# Unblank the screen
		echo disp0 > $DISPLAY/name
		echo blank > $DISPLAY/command
		echo 0 > $DISPLAY/param
		echo 1 > $DISPLAY/start
	fi
fi

