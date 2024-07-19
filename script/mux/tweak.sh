#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/device.sh

. /opt/muos/script/var/global/setting_advanced.sh
. /opt/muos/script/var/global/setting_general.sh

if [ "$(cat /opt/muos/config/brightness.txt)" -lt 1 ]; then
	/opt/muos/device/"$DEVICE_TYPE"/input/combo/bright.sh U
fi

if [ "$(cat /tmp/mux_colour_temp)" -ne "$GC_GEN_COLOUR" ]; then
	echo "$GC_GEN_COLOUR" >/sys/class/disp/disp/attr/color_temperature
	echo "$GC_GEN_COLOUR" >/tmp/mux_colour_temp
fi

if [ "$(cat /tmp/mux_hdmi_mode)" -ne "$GC_GEN_HDMI" ]; then
	if [ "$GC_GEN_HDMI" -gt -1 ]; then
		killall hdmi_start.sh
		/opt/muos/device/"$DEVICE_TYPE"/script/hdmi_stop.sh
		if [ "$DC_DEV_HDMI" -eq 1 ]; then
			/opt/muos/device/"$DEVICE_TYPE"/script/hdmi_start.sh &
		fi
	else
		if pgrep -f "hdmi_start.sh" >/dev/null; then
			killall hdmi_start.sh
			/opt/muos/device/"$DEVICE_TYPE"/script/hdmi_stop.sh
		fi
	fi
	echo "$GC_GEN_HDMI" >/tmp/mux_hdmi_mode
fi

if [ "$(cat /tmp/mux_adb_mode)" -ne "$GC_ADV_ANDROID" ]; then
	if [ "$GC_ADV_ANDROID" -eq 1 ]; then
		/opt/muos/device/"$DEVICE_TYPE"/script/adb.sh &
	else
		killall -q adbd
	fi
	echo "$GC_ADV_ANDROID" >/tmp/mux_adb_mode
fi
