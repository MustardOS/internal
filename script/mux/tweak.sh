#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

COLOUR=$(parse_ini "$CONFIG" "settings.general" "colour")
echo "$COLOUR" > /sys/class/disp/disp/attr/color_temperature

HDMI_STATE=$(parse_ini "$CONFIG" "settings.general" "hdmi")
if [ "$HDMI_STATE" -gt -1 ]; then
	killall hdmi_start.sh
	/opt/muos/device/"$DEVICE"/script/hdmi_stop.sh
	SUPPORT_HDMI=$(parse_ini "$DEVICE_CONFIG" "device" "hdmi")
	if [ "$SUPPORT_HDMI" -eq 1 ]; then
		/opt/muos/device/"$DEVICE"/script/hdmi_start.sh &
	fi
else
	if pgrep -f "hdmi_start.sh" > /dev/null; then
		killall hdmi_start.sh
		/opt/muos/device/"$DEVICE"/script/hdmi_stop.sh
	fi
fi

