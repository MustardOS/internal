#!/bin/sh

. /opt/muos/script/var/func.sh

WIDTH="$(GET_VAR "device" "screen/width")"
HEIGHT="$(GET_VAR "device" "screen/height")"

HAS_PLUGGED=/tmp/hdmi_has_plugged

if [ "$(cat "$HAS_PLUGGED")" -eq 1 ]; then
	# Switch off HDMI
	DISPLAY_WRITE disp0 switch "1 0"
	XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"

	# Reset the display
	FB_SWITCH "$WIDTH" "$HEIGHT" 32

	# Stupid fucking specific RG28XX bullshit
	echo "U:${WIDTH}x${HEIGHT}p-59" >/sys/class/graphics/fb0/mode
	printf 1 >/run/muos/device/screen/rotate
	printf "%s" "$WIDTH" >/run/muos/device/screen/width
	printf "%s" "$HEIGHT" >/run/muos/device/screen/height
fi
