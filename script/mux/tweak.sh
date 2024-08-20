#!/bin/sh

. /opt/muos/script/var/func.sh

if [ "$(cat /opt/muos/config/brightness.txt)" -lt 1 ]; then
	/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/bright.sh U
fi

if [ "$(cat /tmp/mux_colour_temp)" -ne "$(GET_VAR "global" "settings/general/colour")" ]; then
	GET_VAR "global" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature
	GET_VAR "global" "settings/general/colour" >/tmp/mux_colour_temp
fi

if [ "$(cat /tmp/mux_hdmi_mode)" -ne "$(GET_VAR "global" "settings/general/hdmi")" ]; then
	if [ "$(GET_VAR "global" "settings/general/hdmi")" -gt -1 ]; then
		killall hdmi_start.sh
		/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/hdmi_stop.sh
		if [ "$(GET_VAR "device" "board/hdmi")" -eq 1 ]; then
			/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/hdmi_start.sh &
		fi
	else
		if pgrep -f "hdmi_start.sh" >/dev/null; then
			killall hdmi_start.sh
			/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/hdmi_stop.sh
		fi
	fi
	GET_VAR "global" "settings/general/hdmi" >/tmp/mux_hdmi_mode
fi

if [ "$(cat /tmp/mux_adb_mode)" -ne "$(GET_VAR "global" "settings/advanced/android")" ]; then
	if [ "$(GET_VAR "global" "settings/advanced/android")" -eq 1 ]; then
		/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/adb.sh &
	else
		killall -q adbd
	fi
	GET_VAR "global" "settings/advanced/android" >/tmp/mux_adb_mode
fi
