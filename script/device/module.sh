#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")
NET_NAME=$(GET_VAR "device" "network/name")

depmod -a 2>/dev/null

case "$1" in
	load)
		case "$BOARD_NAME" in
			rg*)
				modprobe -q "$NET_NAME"
				modprobe -q mali_kbase
				modprobe -q squashfs

				GPU_PATH="/sys/devices/platform/gpu"

				echo always_on >"$GPU_PATH/power_policy"
				echo 648000000 >"$GPU_PATH/devfreq/gpu/min_freq"
				echo 648000000 >"$GPU_PATH/devfreq/gpu/max_freq"
				;;
			tui*)
				modprobe -q "$NET_NAME"
				modprobe -q dc_sunxi
				case "$BOARD_NAME" in
					*brick) /usr/bin/trimui_inputd_brick & ;;
					*spoon) /usr/bin/trimui_inputd_smart_pro & ;;
				esac
				;;
			*zero28)
				modprobe -q "$NET_NAME"
				modprobe -q fuse
				modprobe -q simplepad
				;;
			*) ;;
		esac
		;;

	unload)
		case "$BOARD_NAME" in
			rg*)
				modprobe -qr "$NET_NAME"
				modprobe -qr mali_kbase
				modprobe -qr squashfs
				;;
			tui*)
				modprobe -qr "$NET_NAME"
				modprobe -qr dc_sunxi
				case "$BOARD_NAME" in
					*brick) pkill -x trimui_inputd_brick ;;
					*spoon) pkill -x trimui_inputd_smart_pro ;;
				esac
				;;
			*zero28)
				modprobe -qr "$NET_NAME"
				modprobe -qr fuse
				modprobe -qr simplepad
				;;
			*) ;;
		esac
		;;

	*) echo "Usage: $0 {load|unload}" >&2 && exit 1 ;;
esac
