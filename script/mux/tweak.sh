#!/bin/sh

. /opt/muos/script/var/func.sh

killall muhotkey # (input.sh will restart it)

C_BRIGHT="$(cat /opt/muos/config/brightness.txt)"
if [ "$C_BRIGHT" -lt 1 ]; then
	/opt/muos/device/current/input/combo/bright.sh U
else
	/opt/muos/device/current/input/combo/bright.sh "$C_BRIGHT"
fi

GET_VAR "global" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature

if [ "$(GET_VAR "global" "settings/general/hdmi")" -gt -1 ]; then
	killall hdmi_start.sh
	/opt/muos/device/current/script/hdmi_stop.sh
	if [ "$(GET_VAR "device" "board/hdmi")" -eq 1 ]; then
		/opt/muos/device/current/script/hdmi_start.sh &
	fi
else
	if pgrep -f "hdmi_start.sh" >/dev/null; then
		killall hdmi_start.sh
		/opt/muos/device/current/script/hdmi_stop.sh
	fi
fi

/opt/muos/script/system/usb.sh &

# Set the device specific SDL Controller Map
/opt/muos/script/mux/sdl_map.sh &
