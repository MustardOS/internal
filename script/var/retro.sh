#!/bin/sh

[ -n "${MUOS_RETRO_LOADED-}" ] && return 0
MUOS_RETRO_LOADED=1
[ -n "${MUOS_DISPLAY_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/display.sh"
[ -n "${MUOS_GOVERNOR_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/governor.sh"

SETUP_APP() {
	printf "app\n" >"$ACT_GO"

	GOV_GO="$MUOS_RUN_DIR/governor"
	[ -e "$GOV_GO" ] && cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"

	HOME="$(GET_VAR "device" "board/home")"
	export HOME

	XDG_CONFIG_HOME="$HOME/.config"
	export XDG_CONFIG_HOME

	SET_VAR "system" "foreground_process" "$1"

	if [ -n "${2:-}" ]; then
		SETUP_SDL_ENVIRONMENT "$2"
	else
		SETUP_SDL_ENVIRONMENT
	fi
}

UPDATE_RA_VALUE() {
	BUTTON_NAME=$1
	EXPECTED_VALUE=$2
	RA_DEV_CONF=$3

	# Read and update current value if it doesn't match the expected value
	if ! grep -q "^$BUTTON_NAME = \"$EXPECTED_VALUE\"" "$RA_DEV_CONF"; then
		sed -i "s|^$BUTTON_NAME = \".*\"|$BUTTON_NAME = \"$EXPECTED_VALUE\"|" "$RA_DEV_CONF"
	fi
}

DETECT_CONTROL_SWAP() {
	RA_DEV_CONF="$DEVICE_CONTROL_DIR/retroarch.device.cfg"
	CON_GO="$MUOS_RUN_DIR/controller"
	IS_SWAP=0

	DO_SWAP() {
		/opt/muos/script/mux/swap_abxy.sh "$RA_DEV_CONF"
		IS_SWAP=1
	}

	if [ -e "$CON_GO" ]; then
		IFS= read -r CON_VAL <"$CON_GO"
		case "$CON_VAL" in
			modern) DO_SWAP ;;
			retro) ;;
			*) [ "$(GET_VAR "config" "settings/remap/layout")" -eq 1 ] && DO_SWAP ;;
		esac
	else
		[ "$(GET_VAR "config" "settings/remap/layout")" -eq 1 ] && DO_SWAP
	fi

	printf "%s\n" "$IS_SWAP"
}

CONFIGURE_RETROARCH() {
	RA_CONF="$MUOS_SHARE_DIR/info/config/retroarch.cfg"
	RA_DEF="$MUOS_SHARE_DIR/emulator/retroarch/retroarch.default.cfg"
	RA_CONTROL="$DEVICE_CONTROL_DIR/retroarch"
	RA_AUTOCONFIG_DIR="$MUOS_SHARE_DIR/emulator/retroarch/autoconfig/udev"
	RA_AUTOCONFIG="$RA_AUTOCONFIG_DIR/muOS-Keys.cfg"
	RA_DEVICE_AUTOCONFIG="$DEVICE_CONTROL_DIR/muOS-Keys.cfg"

	# Check if the default RetroArch configuration exists.
	[ ! -f "$RA_CONF" ] && cp "$RA_DEF" "$RA_CONF"

	# Set the device specific SDL Controller Map
	/opt/muos/script/mux/sdl_map.sh

	mkdir -p "$RA_AUTOCONFIG_DIR"
	if [ -f "$RA_DEVICE_AUTOCONFIG" ]; then
		cp -f "$RA_DEVICE_AUTOCONFIG" "$RA_AUTOCONFIG" || rm -f "$RA_AUTOCONFIG"
	else
		RA_INPUT_VENDOR=
		RA_INPUT_PRODUCT=

		for RA_INPUT_EVENT in /sys/class/input/event*; do
			[ -r "$RA_INPUT_EVENT/device/name" ] || continue
			IFS= read -r RA_INPUT_NAME <"$RA_INPUT_EVENT/device/name"
			[ "$RA_INPUT_NAME" = "muOS-Keys" ] || continue
			[ -r "$RA_INPUT_EVENT/device/id/vendor" ] || continue
			[ -r "$RA_INPUT_EVENT/device/id/product" ] || continue

			IFS= read -r RA_INPUT_VENDOR_HEX <"$RA_INPUT_EVENT/device/id/vendor"
			IFS= read -r RA_INPUT_PRODUCT_HEX <"$RA_INPUT_EVENT/device/id/product"
			case "$RA_INPUT_VENDOR_HEX:$RA_INPUT_PRODUCT_HEX" in
				:* | *: | *[!0-9A-Fa-f:]*) continue ;;
			esac

			RA_INPUT_VENDOR=$(printf '%d' "0x$RA_INPUT_VENDOR_HEX")
			RA_INPUT_PRODUCT=$(printf '%d' "0x$RA_INPUT_PRODUCT_HEX")
			break
		done

		if [ -n "$RA_INPUT_VENDOR" ] && [ -n "$RA_INPUT_PRODUCT" ]; then
			RA_AUTOCONFIG_TMP="$RA_AUTOCONFIG.tmp.$$"
			{
				printf '%s\n' 'input_driver = "udev"'
				printf '%s\n' 'input_joypad_driver = "udev"'
				printf '%s\n' 'input_device = "muOS-Keys"'
				printf 'input_vendor_id = "%s"\n' "$RA_INPUT_VENDOR"
				printf 'input_product_id = "%s"\n' "$RA_INPUT_PRODUCT"
				awk '
					$2 == "=" && $3 != "\"nul\"" && $1 ~ /^input_player1_/ {
						key = $1
						sub(/^input_player1_/, "input_", key)
						if (key ~ /^input_(a|b|x|y|select|start|up|down|left|right|l|r|l2|r2|l3|r3)_btn$/ ||
							key ~ /^input_[lr]_[xy]_(plus|minus)_axis$/) print key " = " $3
					}
				' "$RA_CONTROL.device.cfg"
			} >"$RA_AUTOCONFIG_TMP" && mv -f "$RA_AUTOCONFIG_TMP" "$RA_AUTOCONFIG" ||
				rm -f "$RA_AUTOCONFIG"
			rm -f "$RA_AUTOCONFIG_TMP"
		else
			rm -f "$RA_AUTOCONFIG"
		fi
	fi

	# Modify the RetroArch settings for device resolution output
	RA_WIDTH="$(GET_VAR "device" "screen/width")"
	RA_HEIGHT="$(GET_VAR "device" "screen/height")"

	(
		printf "video_fullscreen_x = \"%s\"\n" "$RA_WIDTH"
		printf "video_fullscreen_y = \"%s\"\n" "$RA_HEIGHT"
		printf "video_window_auto_width_max = \"%s\"\n" "$RA_WIDTH"
		printf "video_window_auto_height_max = \"%s\"\n" "$RA_HEIGHT"
		printf "custom_viewport_width = \"%s\"\n" "$RA_WIDTH"
		printf "custom_viewport_height = \"%s\"\n" "$RA_HEIGHT"
		if [ "$RA_WIDTH" -ge 1280 ]; then
			printf "rgui_aspect_ratio = \"%s\"\n" "1"
		else
			printf "rgui_aspect_ratio = \"%s\"\n" "0"
		fi
	) >"$RA_CONTROL.resolution.cfg"

	# Modify the RetroArch threaded video option based on content settings
	RAC_GO="$MUOS_RUN_DIR/retroarch"
	if [ -f "$RAC_GO" ]; then
		IFS= read -r RAC_VAL <"$RAC_GO"
		sed -i '/^video_threaded = /d' "$RA_CONF"
		printf 'video_threaded = "%s"\n' "$RAC_VAL" >>"$RA_CONF"
	fi

	# Include default button mappings from retroarch.device.cfg. Settings in the
	# retroarch.cfg will take precedence. Modified settings will save to the main
	# retroarch.cfg, not the included retroarch.device.cfg file.
	RA_TYPES="device resolution"

	# Create a temporary config file with all matching lines from the original config,
	# excluding any existing include lines for the given RetroArch types in the var.
	TMP_RA_CONF=$(mktemp) || return 1
	(
		trap 'rm -f "$TMP_RA_CONF"' EXIT

		# Exclude any existing include lines for the given RetroArch types.
		for TYPE in $RA_TYPES; do
			printf '#include "%s.%s.cfg"\n' "$RA_CONTROL" "$TYPE"
		done | grep -vFf - "$RA_CONF" >"$TMP_RA_CONF"

		# Append the required include lines so they are always present.
		for TYPE in $RA_TYPES; do
			printf '#include "%s.%s.cfg"\n' "$RA_CONTROL" "$TYPE" >>"$TMP_RA_CONF"
		done

		# Replace the original config with the modified version.
		mv "$TMP_RA_CONF" "$RA_CONF"
	) || {
		rm -f "$TMP_RA_CONF"
		return 1
	}

	# Set kiosk mode value based on current configuration.
	case "$(GET_VAR "kiosk" "content/retroarch")" in
		1) KIOSK_MODE=true ;;
		*) KIOSK_MODE=false ;;
	esac
	sed -i "s/^kiosk_mode_enable = \".*\"$/kiosk_mode_enable = \"$KIOSK_MODE\"/" "$RA_CONF"

	# Re-define the symlink to current configuration.
	HOME_CFG="$(GET_VAR "device" "board/home")/.config"

	# Purge it just in case it was created by something else!
	rm -rf "$HOME_CFG/retroarch"
	ln -s "$MUOS_SHARE_DIR/emulator/retroarch" "$HOME_CFG/retroarch"
	rm -f "$MUOS_SHARE_DIR/emulator/retroarch/retroarch.cfg"
	ln -s "$MUOS_SHARE_DIR/info/config/retroarch.cfg" "$MUOS_SHARE_DIR/emulator/retroarch/retroarch.cfg"

	EXTRA_ARGS=""
	APPEND_LIST=""

	# The following will stop auto load from happening if they hold A on content
	AUTOLOAD_CONF="$(dirname "$RA_CONF")/retroarch.autoload.cfg"
	if [ -e "/tmp/ra_no_load" ]; then
		printf "savestate_auto_load = \"false\"\n" >"$AUTOLOAD_CONF"
		APPEND_LIST="${APPEND_LIST}${APPEND_LIST:+|}$AUTOLOAD_CONF"
	fi

	# The following will load a users retro achievement settings if saved
	CHEEVOS_CONF="$(dirname "$RA_CONF")/retroarch.cheevos.cfg"
	[ -e "$CHEEVOS_CONF" ] && APPEND_LIST="${APPEND_LIST}${APPEND_LIST:+|}$CHEEVOS_CONF"

	[ -n "$APPEND_LIST" ] && EXTRA_ARGS="--appendconfig=$APPEND_LIST"
	printf '%s\n' "$EXTRA_ARGS"
}

CHECK_EXIST() {
	[ -w "$2" ] || return 0
	GET_VAR "config" "$1" >"$2"
}

KERNEL_TUNING() {
	CHECK_EXIST "danger/vmswap" "/proc/sys/vm/swappiness"
	CHECK_EXIST "danger/dirty_ratio" "/proc/sys/vm/dirty_ratio"
	CHECK_EXIST "danger/dirty_back_ratio" "/proc/sys/vm/dirty_background_ratio"
	CHECK_EXIST "danger/cache_pressure" "/proc/sys/vm/vfs_cache_pressure"

	CHECK_EXIST "danger/nomerges" "/sys/block/$1/queue/nomerges"
	CHECK_EXIST "danger/nr_requests" "/sys/block/$1/queue/nr_requests"
	CHECK_EXIST "danger/iostats" "/sys/block/$1/queue/iostats"

	CHECK_EXIST "danger/idle_flush" "/proc/sys/vm/laptop_mode"
	CHECK_EXIST "danger/page_cluster" "/proc/sys/vm/page-cluster"
	CHECK_EXIST "danger/child_first" "/proc/sys/kernel/sched_child_runs_first"
	CHECK_EXIST "danger/time_slice" "/proc/sys/kernel/sched_rr_timeslice_ms"
	CHECK_EXIST "danger/tune_scale" "/proc/sys/kernel/sched_tunable_scaling"

	if [ -b "/dev/$1" ]; then
		blockdev --setra "$(GET_VAR "config" "danger/read_ahead")" "/dev/$1"
	fi
}

