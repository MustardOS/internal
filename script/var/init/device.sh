#!/bin/sh

USAGE() {
	printf 'Usage: %s {init|save}\n' "$0" >&2
	exit 1
}

[ "$#" -eq 1 ] || USAGE

case "$1" in
	init | save) ;;
	*) USAGE ;;
esac

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/init/system.sh

ACTION="$1"

CONFIG_CLEARED=0
CONFIG_FILE="$DEVICE_CONFIG"

AUDIO_VARS="pf_internal ob_internal pf_external ob_external control channel min max"
BATTERY_VARS="boot_mode capacity health voltage charger"
CPU_VARS="cores default governor scaler sampling_rate up_threshold sampling_down_factor io_is_busy sampling_rate_default up_threshold_default sampling_down_factor_default io_is_busy_default"
BOARD_VARS="name home network bluetooth portmaster lid hdmi event debugfs rtc rumble udc"
INPUT_VARS="ev0 ev1 axis"
INPUT_CODE_DPAD_VARS="up down left right"
INPUT_CODE_ANALOG_LEFT_VARS="up down left right click"
INPUT_CODE_ANALOG_RIGHT_VARS="up down left right click"
INPUT_CODE_BUTTON_VARS="a b c x y z l1 l2 l3 r1 r2 r3 menu_short menu_long select start power_short power_long vol_up vol_down"
INPUT_TYPE_DPAD_VARS="up down left right"
INPUT_TYPE_ANALOG_LEFT_VARS="up down left right click"
INPUT_TYPE_ANALOG_RIGHT_VARS="up down left right click"
INPUT_TYPE_BUTTON_VARS="a b c x y z l1 l2 l3 r1 r2 r3 menu_short menu_long select start power_short power_long vol_up vol_down"
LED_VARS="normal low"
MUX_VARS="width height"
NETWORK_VARS="module name type iface state"
SCREEN_VARS="device hdmi bright width height rotate wait"
SDL_VARS="scaler rotation blitter_disabled"
STORAGE_BOOT_VARS="active dev sep num mount type"
STORAGE_ROM_VARS="active dev sep num mount type"
STORAGE_ROOT_VARS="active dev sep num mount type"
STORAGE_SDCARD_VARS="active dev sep num mount type"
STORAGE_USB_VARS="active dev sep num mount type"

for INIT in audio battery cpu board input input/code/dpad input/code/analog/left input/code/analog/right input/code/button input/type/dpad input/type/analog/left input/type/analog/right input/type/button led mux network screen sdl storage/boot storage/rom storage/root storage/sdcard storage/usb; do
	case $INIT in
		audio) VARS="$AUDIO_VARS" ;;
		battery) VARS="$BATTERY_VARS" ;;
		cpu) VARS="$CPU_VARS" ;;
		board) VARS="$BOARD_VARS" ;;
		input) VARS="$INPUT_VARS" ;;
		input/code/dpad) VARS="$INPUT_CODE_DPAD_VARS" ;;
		input/code/analog/left) VARS="$INPUT_CODE_ANALOG_LEFT_VARS" ;;
		input/code/analog/right) VARS="$INPUT_CODE_ANALOG_RIGHT_VARS" ;;
		input/code/button) VARS="$INPUT_CODE_BUTTON_VARS" ;;
		input/type/dpad) VARS="$INPUT_TYPE_DPAD_VARS" ;;
		input/type/analog/left) VARS="$INPUT_TYPE_ANALOG_LEFT_VARS" ;;
		input/type/analog/right) VARS="$INPUT_TYPE_ANALOG_RIGHT_VARS" ;;
		input/type/button) VARS="$INPUT_TYPE_BUTTON_VARS" ;;
		led) VARS="$LED_VARS" ;;
		mux) VARS="$MUX_VARS" ;;
		network) VARS="$NETWORK_VARS" ;;
		screen) VARS="$SCREEN_VARS" ;;
		sdl) VARS="$SDL_VARS" ;;
		storage/boot) VARS="$STORAGE_BOOT_VARS" ;;
		storage/rom) VARS="$STORAGE_ROM_VARS" ;;
		storage/root) VARS="$STORAGE_ROOT_VARS" ;;
		storage/sdcard) VARS="$STORAGE_SDCARD_VARS" ;;
		storage/usb) VARS="$STORAGE_USB_VARS" ;;
		*)
			printf "'%s' is unknown to %s\n" "$INIT" "$(basename "$0" .sh)"
			continue
			;;
	esac

	case "$ACTION" in
		init)
			BASE_DIR="/run/muos/$(basename "$0" .sh)/$INIT"
			mkdir -p "$BASE_DIR"
			for VAR in $VARS; do
				VAR_VALUE=$(PARSE_INI "$CONFIG_FILE" "$(echo "$INIT" | sed 's/\//./g')" "$VAR")
				SET_VAR "$(basename "$0" .sh)" "$INIT/$VAR" "$VAR_VALUE"
			done
			chmod -R 755 "$BASE_DIR"
			;;
		save)
			if [ $CONFIG_CLEARED -eq 0 ]; then
				: >"$CONFIG_FILE"
				CONFIG_CLEARED=1
			fi
			KEY_VALUES=""
			for VAR in $VARS; do
				VALUE=$(GET_VAR "$(basename "$0" .sh)/$INIT" "$VAR")
				KEY_VALUES=$(printf "%s\n%s" "$KEY_VALUES" "$VAR = $VALUE")
			done
			printf "[%s]%s\n\n" "$(echo "$INIT" | sed 's/\//./g')" "$KEY_VALUES" >>"$CONFIG_FILE"
			;;
	esac
done
