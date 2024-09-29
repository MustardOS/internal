#!/bin/sh

. /opt/muos/script/var/func.sh

HAS_PLUGGED=/tmp/hdmi_has_plugged

if [ "$(cat "$HAS_PLUGGED")" -eq 1 ]; then
	# Switch audio to internal
	XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"

	# Stupid fucking specific RG28XX bullshit
	printf 1 >/run/muos/device/screen/rotate
	printf 480 >/run/muos/device/screen/width
	printf 640 >/run/muos/device/screen/height
	printf 1 >/run/muos/device/sdl/rotation
	printf 1 >/run/muos/device/sdl/scaler
	printf 0 >/run/muos/device/sdl/blitter_disabled

	# Switch off HDMI
	DISPLAY_WRITE disp0 switch "1 0"

	# Reset the display
	echo "U:480x640p-59" >/sys/class/graphics/fb0/mode
fi
