#!/bin/sh

. /opt/muos/script/var/func.sh

HK_COMBO() {
	[ -z "$1" ] && return 0

	case "$(GET_VAR "device" "board/name")" in
		rg*) COMBO_FILE="$MUOS_SHARE_DIR/hotkey/rg.ini" ;;
		tui*) COMBO_FILE="$MUOS_SHARE_DIR/hotkey/tui.ini" ;;
		*) return 0 ;;
	esac

	[ ! -r "$COMBO_FILE" ] && return 0

	awk -F= -v id="$1" '
		$1 == id { print $2; found=1; exit }
		END { if (!found) exit 1 }
	' "$COMBO_FILE"
}

UPDATE_HOTKEY() {
	JSON_FILE="$MUOS_SHARE_DIR/hotkey/$1.json"
	[ ! -f "$JSON_FILE" ] && return 1

	NEW_COMBO=$(HK_COMBO "$(GET_VAR "config" "settings/hotkey/$1")")
	[ -z "$NEW_COMBO" ] && return 1

	JSON_TYPE=$(echo "$1" | tr '[:lower:]' '[:upper:]')
	TEMP_FILE="/tmp/new_$1.tmp"

	if ! jq --arg key "$JSON_TYPE" --argjson combo "$NEW_COMBO" '.[$key].inputs = $combo' \
		"$JSON_FILE" >"$TEMP_FILE" 2>/dev/null; then
		rm -f "$TEMP_FILE"
		return 1
	fi

	if ! cmp -s "$JSON_FILE" "$TEMP_FILE"; then
		mv "$TEMP_FILE" "$JSON_FILE"
		return 0
	else
		rm -f "$TEMP_FILE"
		return 1
	fi
}

UPDATE_HOTKEY "screenshot"
UPDATE_HOTKEY "dpad_toggle"

rm -rf "/tmp/wake_cpu_gov"
HOTKEY restart

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

# Swap the speaker audio if set
/opt/muos/script/device/speaker.sh &

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

SET_DEFAULT_GOVERNOR
