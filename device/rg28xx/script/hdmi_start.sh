#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

HDMI_STATE=$(parse_ini "$DEVICE_CONFIG" "screen" "hdmi")
HDMI_MODE=$(parse_ini "$CONFIG" "settings.general" "hdmi")

DISPLAY="/sys/kernel/debug/dispdbg"

FG_PROC="/tmp/fg_proc"

RESET_DISP=0

SWITCHED_ON=0
SWITCHED_OFF=0

while true; do
	if [ "$(cat "$HDMI_STATE")" = "HDMI=1" ]; then
		SWITCHED_OFF=0

		if [ $SWITCHED_ON -eq 0 ]; then
			RESET_DISP=0

			# Switch on HDMI
			echo disp0 > $DISPLAY/name
			echo switch > $DISPLAY/command
			echo 4 $HDMI_MODE > $DISPLAY/param
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
			if [ $RESET_DISP -eq 0 ]; then
				fbset -g 1280 720 1280 1440 32
				fbset -g 640 480 640 960 32
				fbset -g 1280 720 1280 1440 32
				fbset -g 640 480 640 960 32
				RESET_DISP=1
			fi

			SWITCHED_ON=1
		fi
	else
		SWITCHED_ON=0

		if [ $SWITCHED_OFF -eq 0 ]; then
			RESET_DISP=0

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

			sed -i -E 's/(defaults\.(ctl|pcm)\.card) 2/\1 0/g' /usr/share/alsa/alsa.conf
			alsactl kill quit

			if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" > /dev/null; then
   				pkill -CONT "playbgm.sh"
			fi

			# Reset the display
			if [ $RESET_DISP -eq 0 ]; then
				fbset -g 1280 720 1280 1440 32
				fbset -g 640 480 640 960 32
				fbset -g 1280 720 1280 1440 32
				fbset -g 640 480 640 960 32
				RESET_DISP=1
			fi

			SWITCHED_OFF=1
		fi
	fi
	sleep 3
done

