#!/bin/sh

. /opt/muos/script/var/func.sh

WIDTH="$(GET_VAR "device" "screen/width")"
HEIGHT="$(GET_VAR "device" "screen/height")"

SWITCHED_ON=0
SWITCHED_OFF=0

IN_USE=/tmp/hdmi_in_use
HAS_PLUGGED=/tmp/hdmi_has_plugged
DO_REFRESH=/tmp/hdmi_do_refresh

while true; do
	if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" = "HDMI=1" ]; then
		if [ "$(GET_VAR "global" "settings/advanced/hdmi_output")" -eq 0 ]; then
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_external")"
			XDG_RUNTIME_DIR="/var/run" wpctl set-volume "$(GET_VAR "audio" "nid_external")" 100%
		else
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"
		fi

		echo "1" >$HAS_PLUGGED
		SWITCHED_OFF=0

		if [ $SWITCHED_ON -eq 0 ]; then
			echo "1" >$IN_USE

			# Switch on HDMI
			DISPLAY_WRITE disp0 switch "4 $(GET_VAR "global" "settings/general/hdmi") 0 0 0x4 0x201 0 1 0 8"

			# Reset the display
			FB_SWITCH "$WIDTH" "$HEIGHT" 32

			SWITCHED_ON=1
			echo "1" >$DO_REFRESH
		fi
	else
		if [ "$(cat "$HAS_PLUGGED")" -eq 1 ]; then
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"

			echo "0" >$HAS_PLUGGED
			SWITCHED_ON=0

			if [ $SWITCHED_OFF -eq 0 ]; then
				echo "0" >$IN_USE

				# Switch off HDMI
				DISPLAY_WRITE disp0 switch "1 0"

				# Reset the display
				FB_SWITCH "$WIDTH" "$HEIGHT" 32

				SWITCHED_OFF=1
				echo "1" >$DO_REFRESH
			fi
		fi
	fi
	sleep 2
done
