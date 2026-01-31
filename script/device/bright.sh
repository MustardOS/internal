#!/bin/sh

# See, https://www.man7.org/linux/man-pages/man1/flock.1.html
exec 9>/tmp/bright.lock
flock -n 9 || exit 0

. /opt/muos/script/var/func.sh

DEVICE_MODE=$(GET_VAR "config" "boot/device_mode")
{ [ -z "$1" ] || [ "$DEVICE_MODE" -ne 0 ]; } && exit 0

INC_BRIGHT=$(GET_VAR "config" "settings/advanced/incbright")
CURR_BRIGHT=$(GET_VAR "config" "settings/general/brightness")
MAX_BRIGHT=$(GET_VAR "device" "screen/bright")
BOARD_NAME=$(GET_VAR "device" "board/name")

FB_BLANK="/tmp/fb_blank"
MUX_BLANK="/tmp/mux_blank"

CHARGER="/tmp/charger_bright"

SAFE_BRIGHT=10

# This is the most stupidest thing yet, some devices actually invert
# their brightness method, so now we have to invert our calculations
INVERT_BRIGHT=0
case "$BOARD_NAME" in
	mgx*) INVERT_BRIGHT=1 ;;
esac

MAP_BRIGHT() {
	V=$1
	[ "$INVERT_BRIGHT" -eq 0 ] && {
		printf "%s" "$V"
		return
	}
	printf "%s" $((MAX_BRIGHT - V))
}

SET_BLANK() {
	TARGET_BLANK=$1

	[ "$(cat "$FB_BLANK" 2>/dev/null || printf 0)" -eq "$TARGET_BLANK" ] && return

	echo "$TARGET_BLANK" >/sys/class/graphics/fb0/blank
	echo "$TARGET_BLANK" >"$FB_BLANK"

	# Please note that the LCD toggles below are not enabled by default on muOS
	# as it causes display panel issues, however feel free to re-enable it...
	case "$TARGET_BLANK" in
		4)
			touch "$MUX_BLANK"
			LCD_DISABLE
			;;
		*)
			rm -f "$MUX_BLANK"
			[ "$CURR_BRIGHT" -le "$SAFE_BRIGHT" ] && LCD_ENABLE
			;;
	esac
}

SET_CURRENT() {
	NEW_BRIGHT=$1

	# 1=force reapply display value to LCD
	FORCE=${2:-0}

	HW_BRIGHT=$(MAP_BRIGHT "$NEW_BRIGHT")

	DESIRED_BLANK=$([ "$NEW_BRIGHT" -eq 0 ] && printf 4 || printf 0)
	CURRENT_BLANK=$(cat "$FB_BLANK" 2>/dev/null || printf 0)

	# Keep framebuffer blank state in sync
	[ "$CURRENT_BLANK" -ne "$DESIRED_BLANK" ] && SET_BLANK "$DESIRED_BLANK"

	if [ "$NEW_BRIGHT" -le 0 ]; then
		DISPLAY_WRITE disp0 setbl "$(MAP_BRIGHT 0)"
	else
		# Additional checks to reapply to LCD if forced OR changed (but only when >0)
		if [ "$FORCE" -eq 1 ] || [ "$NEW_BRIGHT" -ne "$CURR_BRIGHT" ]; then
			DISPLAY_WRITE disp0 setbl "$HW_BRIGHT"
		else
			# This is stupid but works...
			# Detect for a specific charger file and new brightness and force blank the LCD
			if [ -e "$CHARGER" ]; then
				DISPLAY_WRITE disp0 setbl "$HW_BRIGHT"
			fi
		fi

		# Okay so we'll try clamping the brightness values...
		# This should NOT affect blanking as we do that above!
		PERSIST="$NEW_BRIGHT"
		[ "$PERSIST" -lt 1 ] && PERSIST=1
		[ "$PERSIST" -gt "$MAX_BRIGHT" ] && PERSIST="$MAX_BRIGHT"

		# Set the new value regardless of previous brightness value!
		SET_VAR "config" "settings/general/brightness" "$PERSIST"
	fi
}

case "$1" in
	R)
		[ "$CURR_BRIGHT" -le "$SAFE_BRIGHT" ] && CURR_BRIGHT=$((CURR_BRIGHT + SAFE_BRIGHT + (INC_BRIGHT * 2)))
		SET_CURRENT "$CURR_BRIGHT" 1
		;;
	U)
		if [ "$CURR_BRIGHT" -gt 0 ]; then
			[ "$CURR_BRIGHT" -le $((INC_BRIGHT - 1)) ] && NEW_BL=$((CURR_BRIGHT + 1)) || NEW_BL=$((CURR_BRIGHT + INC_BRIGHT))
			[ "$NEW_BL" -gt "$MAX_BRIGHT" ] && NEW_BL="$MAX_BRIGHT"
			SET_CURRENT "$NEW_BL"
		else
			SET_CURRENT "$SAFE_BRIGHT" 1
		fi
		;;
	D)
		if [ "$CURR_BRIGHT" -gt 0 ]; then
			[ "$CURR_BRIGHT" -le "$INC_BRIGHT" ] && NEW_BL=$((CURR_BRIGHT - 1)) || NEW_BL=$((CURR_BRIGHT - INC_BRIGHT))
			[ "$NEW_BL" -lt 0 ] && NEW_BL=0
			SET_CURRENT "$NEW_BL"
		fi
		;;
	F)
		LCD_DISABLE && sleep 1 && LCD_ENABLE
		;;
	[0-9]*)
		[ "$1" -eq "$1" ] 2>/dev/null && [ "$1" -ge 0 ] && [ "$1" -le "$MAX_BRIGHT" ] && SET_CURRENT "$1"
		;;
	*) ;;
esac
