#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")
NET_NAME=$(GET_VAR "device" "network/name")

depmod -a 2>/dev/null

LOAD_MODULES() {
	case "$BOARD_NAME" in
		rg*)
		  	modprobe -qf "$NET_NAME"
			modprobe -qf squashfs
			modprobe -qf mali_kbase

			GPU_PATH="/sys/devices/platform/gpu"

			echo always_on >"$GPU_PATH/power_policy"
			echo 648000000 >"$GPU_PATH/devfreq/gpu/min_freq"
			echo 648000000 >"$GPU_PATH/devfreq/gpu/max_freq"
			;;
		*) ;;
	esac
}

UNLOAD_MODULES() {
	case "$BOARD_NAME" in
		rg*)
		  	modprobe -qr "$NET_NAME"
			modprobe -qr mali_kbase
			modprobe -qr squashfs
			;;
		*) ;;
	esac
}

case "$1" in
	load) LOAD_MODULES ;;
	unload) UNLOAD_MODULES ;;
	*) echo "Usage: $0 {load|unload}" >&2 && exit 1 ;;
esac
