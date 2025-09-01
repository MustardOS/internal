#!/bin/sh

. /opt/muos/script/var/func.sh

# hotkey.sh will restart it
killall muhotkey

C_BRIGHT="$(GET_VAR "config" "settings/general/brightness")"
if [ "$C_BRIGHT" -lt 1 ]; then
	/opt/muos/script/device/bright.sh U
else
	/opt/muos/script/device/bright.sh "$C_BRIGHT"
fi

LED_CONTROL_CHANGE

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
	if [ "$(GET_VAR "config" "danger/cardmode")" = "noop" ]; then
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
