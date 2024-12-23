#!/bin/sh

. /opt/muos/script/var/func.sh

WIDTH="$(GET_VAR "device" "screen/width")"
HEIGHT="$(GET_VAR "device" "screen/height")"

SWITCHED_ON=0
SWITCHED_OFF=0

HAS_PLUGGED=/tmp/hdmi_has_plugged
DO_REFRESH=/tmp/hdmi_do_refresh

printf "0" >$HAS_PLUGGED
printf "0" >$DO_REFRESH

while true; do
	if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" = "HDMI=1" ]; then
		if [ "$(GET_VAR "global" "settings/hdmi/audio")" -eq 0 ]; then
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_external")"
			XDG_RUNTIME_DIR="/var/run" wpctl set-volume "$(GET_VAR "audio" "nid_external")" 100%
		else
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"
		fi

		echo "1" >$HAS_PLUGGED
		SWITCHED_OFF=0

		if [ $SWITCHED_ON -eq 0 ]; then
			DISPLAY_WRITE disp0 switch1 "4 $(GET_VAR "global" "settings/hdmi/resolution") $(GET_VAR "global" "settings/hdmi/space") $(GET_VAR "global" "settings/hdmi/depth") 0x4 0x101 0 $(GET_VAR "global" "settings/hdmi/range") $(GET_VAR "global" "settings/hdmi/scan") $(GET_VAR "global" "settings/hdmi/aspect")"

			FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
			case "$FG_PROC_VAL" in
				mux*) FB_SWITCH "$WIDTH" "$HEIGHT" 32 ;;
				*) ;;
			esac

			SWITCHED_ON=1
			echo "1" >$DO_REFRESH
		fi
	else
		if [ "$(cat "$HAS_PLUGGED")" -eq 1 ]; then
			XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"

			echo "0" >$HAS_PLUGGED
			SWITCHED_ON=0

			if [ $SWITCHED_OFF -eq 0 ]; then
				DISPLAY_WRITE disp0 switch "1 0"

				FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
				case "$FG_PROC_VAL" in
					mux*) FB_SWITCH "$WIDTH" "$HEIGHT" 32 ;;
					*) ;;
				esac

				SWITCHED_OFF=1
				echo "1" >$DO_REFRESH
			fi
		fi
	fi
	sleep 2
done
