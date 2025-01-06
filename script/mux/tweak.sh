#!/bin/sh

. /opt/muos/script/var/func.sh

# hotkey.sh will restart it
killall muhotkey

C_BRIGHT="$(cat /opt/muos/config/brightness.txt)"
if [ "$C_BRIGHT" -lt 1 ]; then
	/opt/muos/device/current/input/combo/bright.sh U
else
	/opt/muos/device/current/input/combo/bright.sh "$C_BRIGHT"
fi

GET_VAR "global" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature

if [ "$(GET_VAR "global" "settings/advanced/overdrive")" -eq 1 ]; then
	SET_VAR "device" "audio/max" "200"
else
	SET_VAR "device" "audio/max" "100"
fi

/opt/muos/script/system/usb.sh &

# Set the device specific SDL Controller Map
/opt/muos/script/mux/sdl_map.sh &

/opt/muos/script/system/swapfile.sh &

START_BGM

CARD_MODE_SWITCH() {
	if [ "$(GET_VAR "global" "settings/advanced/cardmode")" = "noop" ]; then
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
