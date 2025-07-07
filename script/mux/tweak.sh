#!/bin/sh

. /opt/muos/script/var/func.sh

# hotkey.sh will restart it
killall muhotkey

C_BRIGHT="$(GET_VAR "config" "settings/general/brightness")"
if [ "$C_BRIGHT" -lt 1 ]; then
	/opt/muos/device/script/bright.sh U
else
	/opt/muos/device/script/bright.sh "$C_BRIGHT"
fi

(
	LED_CONTROL_SCRIPT="/opt/muos/device/script/led_control.sh"

	if [ "$(GET_VAR "config" "settings/general/rgb")" -eq 1 ] && [ "$(GET_VAR "device" "led/rgb")" -eq 1 ]; then
		RGBCONF_SCRIPT="/run/muos/storage/theme/active/rgb/rgbconf.sh"

		TIMEOUT=10
		WAIT=0

		while [ ! -f "$RGBCONF_SCRIPT" ] && [ "$WAIT" -lt "$TIMEOUT" ]; do
			sleep 1
			WAIT=$((WAIT + 1))
		done

		if [ -f "$RGBCONF_SCRIPT" ]; then
			"$RGBCONF_SCRIPT"
		else
			"$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
		fi
	else
		[ -f "$LED_CONTROL_SCRIPT" ] && "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
	fi
) &

GET_VAR "config" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature

if [ "$(GET_VAR "config" "settings/advanced/overdrive")" -eq 1 ]; then
	SET_VAR "device" "audio/max" "200"
else
	SET_VAR "device" "audio/max" "100"
fi

/opt/muos/script/system/usb.sh &

# Set the device specific SDL Controller Map
/opt/muos/script/mux/sdl_map.sh &

# Check both zram and standard swap
/opt/muos/script/system/swap.sh &

CARD_MODE_SWITCH() {
	if [ "$(GET_VAR "config" "settings/advanced/cardmode")" = "noop" ]; then
		echo "noop" >"/sys/block/$1/queue/scheduler"
		echo "write back" >"/sys/block/$1/queue/write_cache"
	else
		echo "deadline" >"/sys/block/$1/queue/scheduler"
		echo "write through" >"/sys/block/$1/queue/write_cache"
	fi
}

CARD_MODE_SWITCH "$(GET_VAR "device" "storage/rom/dev")"
[ "$(GET_VAR "device" "storage/sdcard/active")" -eq 1 ] && CARD_MODE_SWITCH "$(GET_VAR "device" "storage/sdcard/dev")"
[ "$(GET_VAR "device" "storage/usb/active")" -eq 1 ] && CARD_MODE_SWITCH "$(GET_VAR "device" "storage/usb/dev")"
