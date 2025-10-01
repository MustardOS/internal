#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")

LOAD_MODULES() {
	case "$BOARD_NAME" in
		rg*)
			insmod /lib/modules/4.9.170/kernel/drivers/fs/squashfs.ko &
			insmod /lib/modules/4.9.170/kernel/drivers/video/gpu/mali_kbase.ko

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
			rmmod mali_kbase 2>/dev/null
			rmmod squashfs 2>/dev/null
			;;
		*) ;;
	esac
}

case "$1" in
	load) LOAD_MODULES ;;
	unload) UNLOAD_MODULES ;;
	*) echo "Usage: $0 {load|unload}" >&2 && exit 1 ;;
esac
