#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE_MODE=$(GET_VAR "global" "boot/device_mode")
{ [ -z "$1" ] || [ "$DEVICE_MODE" -ne 0 ]; } && exit 0

CURR_BRIGHT=$(GET_VAR "global" "settings/general/brightness")
MAX_BRIGHT=$(GET_VAR "device" "screen/bright")

SET_CURRENT() {
	C_BRIGHT=$1
	[ "$C_BRIGHT" -eq "$CURR_BRIGHT" ] && return

	FB_BLANK="/tmp/fb_blank"
	[ -f "$FB_BLANK" ] && CURR_BLANK=$(cat "$FB_BLANK") || CURR_BLANK=0

	if [ "$C_BRIGHT" -eq 0 ]; then
		touch "/tmp/mux_blank"

		FBB=4
		if [ "$CURR_BLANK" -ne $FBB ]; then
			echo $FBB >/sys/class/graphics/fb0/blank &
			echo $FBB >"$FB_BLANK"
		fi

		DISPLAY_WRITE lcd0 setbl 0 &

		! pgrep -f "muxcharge" >/dev/null && SET_VAR "global" "settings/general/brightness" 0
	else
		rm -f "/tmp/mux_blank"

		FBB=0
		if [ "$CURR_BLANK" -ne $FBB ]; then
			echo $FBB >/sys/class/graphics/fb0/blank &
			echo $FBB >"$FB_BLANK"
		fi

		DISPLAY_WRITE lcd0 setbl "$C_BRIGHT" &

		! pgrep -f "muxcharge" >/dev/null && SET_VAR "global" "settings/general/brightness" "$C_BRIGHT"
	fi
}

case "$1" in
	R)
		[ "$CURR_BRIGHT" -lt 5 ] && CURR_BRIGHT=90
		DISPLAY_WRITE lcd0 setbl "$CURR_BRIGHT" &
		;;
	U)
		if [ "$CURR_BRIGHT" -le 14 ]; then
			NEW_BL=$((CURR_BRIGHT + 1))
		else
			NEW_BL=$((CURR_BRIGHT + 15))
		fi
		[ "$NEW_BL" -gt "$MAX_BRIGHT" ] && NEW_BL=$MAX_BRIGHT
		SET_CURRENT "$NEW_BL"
		;;
	D)
		if [ "$CURR_BRIGHT" -le 15 ]; then
			NEW_BL=$((CURR_BRIGHT - 1))
		else
			NEW_BL=$((CURR_BRIGHT - 15))
		fi
		[ "$NEW_BL" -lt 0 ] && NEW_BL=0
		SET_CURRENT "$NEW_BL"
		;;
	[0-9]*)
		[ "$1" -ge 0 ] && [ "$1" -le "$MAX_BRIGHT" ] &&
			SET_CURRENT "$1"
		;;
	*)
		printf "Invalid Argument\n\tU) Increase Brightness\n\tD) Decrease Brightness\n"
		;;
esac
