#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE_MODE=$(GET_VAR "config" "boot/device_mode")
[ -z "$1" ] || [ "$DEVICE_MODE" -ne 0 ] && exit 0

CURR_BRIGHT=$(GET_VAR "config" "settings/general/brightness")
MAX_BRIGHT=$(GET_VAR "device" "screen/bright")

FB_BLANK="/tmp/fb_blank"

SET_BLANK() {
	TARGET_BLANK=$1

	[ "$(cat "$FB_BLANK" 2>/dev/null || printf 0)" -eq "$TARGET_BLANK" ] && return

	echo "$TARGET_BLANK" >/sys/class/graphics/fb0/blank
	echo "$TARGET_BLANK" >"$FB_BLANK"

	case "$TARGET_BLANK" in
		4)
			touch /tmp/mux_blank
			LCD_DISABLE
			;;
		*)
			rm -f /tmp/mux_blank
			[ "$CURR_BRIGHT" -lt 5 ] && LCD_ENABLE
			;;
	esac
}

SET_CURRENT() {
	NEW_BRIGHT=$1
	[ "$NEW_BRIGHT" -eq "$CURR_BRIGHT" ] && return

	case "$NEW_BRIGHT" in
		0) SET_BLANK 4 ;;
		*) SET_BLANK 0 ;;
	esac

	DISPLAY_WRITE lcd0 setbl "$NEW_BRIGHT"
	SET_VAR "config" "settings/general/brightness" "$NEW_BRIGHT"
}

case "$1" in
	R)
		[ "$CURR_BRIGHT" -lt 5 ] && CURR_BRIGHT=90
		DISPLAY_WRITE lcd0 setbl "$CURR_BRIGHT"
		;;
	U)
		[ "$CURR_BRIGHT" -le 14 ] && NEW_BL=$((CURR_BRIGHT + 1)) || NEW_BL=$((CURR_BRIGHT + 15))
		[ "$NEW_BL" -gt "$MAX_BRIGHT" ] && NEW_BL=$MAX_BRIGHT
		SET_CURRENT "$NEW_BL"
		;;
	D)
		[ "$CURR_BRIGHT" -le 15 ] && NEW_BL=$((CURR_BRIGHT - 1)) || NEW_BL=$((CURR_BRIGHT - 15))
		[ "$NEW_BL" -lt 0 ] && NEW_BL=0
		SET_CURRENT "$NEW_BL"
		;;
	F)
		LCD_DISABLE && /opt/muos/bin/toybox sleep 1 && LCD_ENABLE
		;;
	[0-9]*)
		[ "$1" -eq "$1" ] 2>/dev/null && [ "$1" -ge 0 ] && [ "$1" -le "$MAX_BRIGHT" ] && SET_CURRENT "$1"
		;;
	*)
		printf "Invalid Argument\n\tU) Increase Brightness\n\tD) Decrease Brightness\n"
		;;
esac
