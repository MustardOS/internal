#!/bin/sh

. /opt/muos/script/var/func.sh

HAS_PLUGGED=/tmp/hdmi_has_plugged

if [ "$(cat "$HAS_PLUGGED")" -eq 1 ]; then
	DISPLAY_WRITE disp0 switch "1 0"
	XDG_RUNTIME_DIR="/var/run" wpctl set-default "$(GET_VAR "audio" "nid_internal")"

	printf 1 >/run/muos/device/screen/rotate
	printf 480 >/run/muos/device/screen/width
	printf 640 >/run/muos/device/screen/height
	printf 1 >/run/muos/device/sdl/rotation
	printf 1 >/run/muos/device/sdl/scaler
	printf 0 >/run/muos/device/sdl/blitter_disabled

	FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
	case "$FG_PROC_VAL" in
		mux*) FB_SWITCH 480 640 32 ;;
		*) ;;
	esac
fi
