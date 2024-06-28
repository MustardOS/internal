#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/device.sh

. /opt/muos/script/var/global/setting_general.sh

echo "$GC_GEN_COLOUR" >/sys/class/disp/disp/attr/color_temperature

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
