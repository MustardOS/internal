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

CONFIG_FILE="$DEVICE_CONFIG"

AUDIO_VARS="pf_internal ob_internal pf_external ob_external control channel min max"
BATTERY_VARS="boot_mode capacity health voltage charger"
CPU_VARS="cores default governor scaler sampling_rate up_threshold sampling_down_factor io_is_busy sampling_rate_default up_threshold_default sampling_down_factor_default io_is_busy_default"
BOARD_VARS="name home network bluetooth portmaster stick lid hdmi event debugfs rtc rumble udc"
INPUT_VARS="general power volume extra axis"
INPUT_ANALOG_LEFT_VARS="up down left right click"
INPUT_ANALOG_RIGHT_VARS="up down left right click"
INPUT_BUTTON_VARS="a b c x y z l1 l2 l3 r1 r2 r3 menu_short menu_long select start power_short power_long vol_up vol_down"
INPUT_DPAD_VARS="up down left right"
INPUT_SDLMAP_VARS="a b x y"
LED_VARS="normal low rgb"
MUX_VARS="width height"
NETWORK_VARS="module name type iface state"
SCREEN_VARS="device hdmi bright width height rotate wait"
SCREEN_INTERNAL_VARS="width height"
SCREEN_EXTERNAL_VARS="width height"
SDL_VARS="scaler rotation blitter_disabled"
STORAGE_VARS="active dev sep num mount type label"

for INIT in audio battery cpu board input input/code/dpad input/code/analog/left input/code/analog/right input/code/button input/type/dpad input/type/analog/left input/type/analog/right input/type/button input/sdlmap/retro input/sdlmap/modern led mux network screen screen/internal screen/external sdl storage/boot storage/rom storage/root storage/sdcard storage/usb; do
	case $INIT in
		audio) VARS="$AUDIO_VARS" ;;
		battery) VARS="$BATTERY_VARS" ;;
		cpu) VARS="$CPU_VARS" ;;
		board) VARS="$BOARD_VARS" ;;
		input) VARS="$INPUT_VARS" ;;
		input/code/dpad) VARS="$INPUT_DPAD_VARS" ;;
		input/code/analog/left) VARS="$INPUT_ANALOG_LEFT_VARS" ;;
		input/code/analog/right) VARS="$INPUT_ANALOG_RIGHT_VARS" ;;
		input/code/button) VARS="$INPUT_BUTTON_VARS" ;;
		input/type/dpad) VARS="$INPUT_DPAD_VARS" ;;
		input/type/analog/left) VARS="$INPUT_ANALOG_LEFT_VARS" ;;
		input/type/analog/right) VARS="$INPUT_ANALOG_RIGHT_VARS" ;;
		input/type/button) VARS="$INPUT_BUTTON_VARS" ;;
		input/sdlmap/retro) VARS="$INPUT_SDLMAP_VARS" ;;
		input/sdlmap/modern) VARS="$INPUT_SDLMAP_VARS" ;;
		led) VARS="$LED_VARS" ;;
		mux) VARS="$MUX_VARS" ;;
		network) VARS="$NETWORK_VARS" ;;
		screen) VARS="$SCREEN_VARS" ;;
		screen/internal) VARS="$SCREEN_INTERNAL_VARS" ;;
		screen/external) VARS="$SCREEN_EXTERNAL_VARS" ;;
		sdl) VARS="$SDL_VARS" ;;
		storage/boot) VARS="$STORAGE_VARS" ;;
		storage/rom) VARS="$STORAGE_VARS" ;;
		storage/root) VARS="$STORAGE_VARS" ;;
		storage/sdcard) VARS="$STORAGE_VARS" ;;
		storage/usb) VARS="$STORAGE_VARS" ;;
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
			KEY_VALUES=""
			for VAR in $VARS; do
				if [ -f "/run/muos/$(basename "$0" .sh)/$INIT/$VAR" ]; then
					VALUE=$(GET_VAR "$(basename "$0" .sh)/$INIT" "$VAR")
				else
					# Use default value for newly added var.
					# (Happens when installing a patch).
					VALUE=$(PARSE_INI "$CONFIG_FILE" "$(echo "$INIT" | sed 's/\//./g')" "$VAR")
				fi
				KEY_VALUES=$(printf "%s\n%s" "$KEY_VALUES" "$VAR = $VALUE")
			done
			printf "[%s]%s\n\n" "$(echo "$INIT" | sed 's/\//./g')" "$KEY_VALUES" >>"$CONFIG_FILE.sav"
			;;
	esac
done

if [ "$ACTION" = save ]; then
	mv -f "$CONFIG_FILE.sav" "$CONFIG_FILE"

	case "$(GET_VAR "global" "settings/advanced/rumble")" in
		2 | 4 | 6) RUMBLE "$(GET_VAR "device" "board/rumble")" 0.3 ;;
		*) ;;
	esac
fi
