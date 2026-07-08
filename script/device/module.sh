#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")
HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_NAME=$(GET_VAR "device" "network/name")

MODULES_DIR="/lib/modules/$(uname -r)"
DEPMOD_STAMP="$MODULES_DIR/depmod.stamp"
if [ ! -f "$DEPMOD_STAMP" ] || [ -n "$(find "$MODULES_DIR" -newer "$DEPMOD_STAMP" -maxdepth 0)" ]; then
	depmod -a 2>/dev/null && touch "$DEPMOD_STAMP"
fi

case "$1" in
	load)
		[ "$HAS_NETWORK" -eq 1 ] && modprobe -q "$NET_NAME"

		case "$BOARD_NAME" in
			rg*)
				modprobe -q mali_kbase
				modprobe -q squashfs

				if [ "$(GET_VAR "config" "settings/advanced/maxgpu")" -eq 1 ]; then
					GPU_PATH="/sys/devices/platform/gpu"
					printf "always_on" >"$GPU_PATH/power_policy"
					printf "648000000" >"$GPU_PATH/devfreq/gpu/min_freq"
					printf "648000000" >"$GPU_PATH/devfreq/gpu/max_freq"
				fi
				;;
			tui*)
				modprobe -q dc_sunxi

				# Check if any trimui_inputd process is already running
				# because this script is typically run with suspend too
				pgrep -f 'trimui_inputd' >/dev/null 2>&1 || /opt/muos/bin/trimui_inputd &
				;;
			mgx*)
				modprobe -q fuse
				modprobe -q simplepad
				modprobe -q dc_sunxi
				;;
		esac
		;;
	unload)
		[ "$HAS_NETWORK" -eq 1 ] && modprobe -qr "$NET_NAME"

		case "$BOARD_NAME" in
			rg*)
				modprobe -qr mali_kbase
				modprobe -qr squashfs
				;;
			mgx*) modprobe -qr simplepad ;;
		esac
		;;
	*)
		printf "Usage: %s {load|unload}\n" "$0" >&2
		exit 1
		;;
esac
