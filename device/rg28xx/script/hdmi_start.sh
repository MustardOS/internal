#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/screen.sh

. /opt/muos/script/var/global/setting_general.sh

FG_PROC="/tmp/fg_proc"

RESET_DISP=0
SWITCHED_ON=0
SWITCHED_OFF=0

while true; do
	if [ "$(cat "$DC_SCR_HDMI")" = "HDMI=1" ]; then
		SWITCHED_OFF=0

		if [ $SWITCHED_ON -eq 0 ]; then
			RESET_DISP=0

			echo "1" >/tmp/hdmi_in_use

			FG_PROC_VAL=$(cat "$FG_PROC")

			if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
				pkill -STOP "playbgm.sh"
				killall -q "mpg123"
			fi

			sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 2/g" /usr/share/alsa/alsa.conf
			alsactl kill quit

			if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
				pkill -CONT "playbgm.sh"
			fi

			# Switch on HDMI
			DISPLAY_WRITE disp0 switch 4

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

			echo "0" >/tmp/hdmi_in_use

			FG_PROC_VAL=$(cat "$FG_PROC")

			if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
				pkill -STOP "playbgm.sh"
				killall -q "mpg123"
			fi

			sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf
			alsactl kill quit

			if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
				pkill -CONT "playbgm.sh"
			fi

			# Switch off HDMI
			DISPLAY_WRITE disp0 switch '1 0'

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
