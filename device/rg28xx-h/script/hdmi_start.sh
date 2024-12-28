#!/bin/sh

. /opt/muos/script/var/func.sh

SWITCHED_ON=0
SWITCHED_OFF=0

DO_REFRESH=/tmp/hdmi_do_refresh
printf "0" >$DO_REFRESH

while true; do
	if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 1 ]; then
		SWITCHED_OFF=0
		if [ $SWITCHED_ON -eq 0 ]; then
			if [ "$(GET_VAR "global" "settings/hdmi/audio")" -eq 0 ]; then
				XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_external")"
				XDG_RUNTIME_DIR="/var/run" wpctl set-volume "$(GET_VAR "audio" "nid_external")" 100%
			else
				XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"
			fi

			DISPLAY_WRITE disp0 switch1 "4 $(GET_VAR "global" "settings/hdmi/resolution") $(GET_VAR "global" "settings/hdmi/space") $(GET_VAR "global" "settings/hdmi/depth") 0x4 0x101 0 $(GET_VAR "global" "settings/hdmi/range") $(GET_VAR "global" "settings/hdmi/scan") 8"
			HDMI_SWITCH

			SWITCHED_ON=1
			echo "1" >$DO_REFRESH
		fi
	else
		SWITCHED_ON=0
		if [ $SWITCHED_OFF -eq 0 ]; then
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"

			DISPLAY_WRITE disp0 switch "1 0"
			FB_SWITCH "$(GET_VAR "device" "screen/internal/width")" "$(GET_VAR "device" "screen/internal/height")" 32

			SWITCHED_OFF=1
			echo "1" >$DO_REFRESH
		fi
	fi
	sleep 1
done &
