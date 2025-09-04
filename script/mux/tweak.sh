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

USB_GADGET_RUN="/opt/muos/script/system/usb_gadget.sh"
LOCK_PID="/run/muos/lock/usb_gadgetd.lock/pid"

GADGET_WD() {
	[ -r "$LOCK_PID" ] && kill -0 "$(cat "$LOCK_PID" 2>/dev/null)" 2>/dev/null
}

case "$(GET_VAR "config" "settings/advanced/usb_function")" in
	none)
		# Disable and remove all usb functions and then stop...
		"$USB_GADGET_RUN" disable
		"$USB_GADGET_RUN" stop
		;;
	adb)
		# Start only if ADB daemon is missing OR watchdog isn't running
		if ! pidof adbd >/dev/null 2>&1 || ! GADGET_WD; then
			"$USB_GADGET_RUN" start
		fi
		;;
	mtp)
		# Same idea as above but for MTP
		if ! pidof umtprd >/dev/null 2>&1 || ! GADGET_WD; then
			"$USB_GADGET_RUN" start
		fi
		;;
	*) ;;
esac

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
