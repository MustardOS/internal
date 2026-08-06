#!/bin/sh
# NEVER_CANCEL: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_IS_NATIVE || FRONTEND stop

COMMAND=$(basename "$0")

USAGE() {
	TASK_ERROR "bad_arguments" "$(printf "Usage: %s <set|clear> [image] [mode]" "$COMMAND")"
	TASK_IS_NATIVE || FRONTEND start custom
	exit 1
}

ALL_DONE() {
	TASK_COMPLETE "$2"
	TASK_IS_NATIVE || FRONTEND start custom
	exit "$1"
}

SET_LOGO() {
	IMAGE="$1"
	MODE="$2"

	[ -f "$IMAGE" ] || {
		TASK_ERROR "missing_image" "$(printf "No such image: %s" "$IMAGE")"
		ALL_DONE 1 "Boot logo unchanged"
	}

	TASK_STATUS "Reading Boot Logo"
	TASK_DETAIL "$(basename "$IMAGE")"
	TASK_PROGRESS 10 100

	BOOT_MOUNT=$(GET_VAR "device" "storage/boot/mount")
	[ -n "$BOOT_MOUNT" ] || ALL_DONE 1 "No boot storage found"

	DEVICE_W=$(GET_VAR "device" "screen/internal/width")
	DEVICE_H=$(GET_VAR "device" "screen/internal/height")

	[ -n "$DEVICE_W" ] || DEVICE_W=$(GET_VAR "device" "screen/width")
	[ -n "$DEVICE_H" ] || DEVICE_H=$(GET_VAR "device" "screen/height")

	TASK_STATUS "Converting for Device"
	TASK_PROGRESS 40 100

	APPLY_LOGO_IMAGE "$IMAGE" "$BOOT_MOUNT/bootlogo.bmp" "$MODE"

	TASK_STATUS "Writing Boot Logo"
	TASK_PROGRESS 100 100

	ALL_DONE 0 "Completed"
}

CLEAR_LOGO() {
	TASK_STATUS "Restoring Theme Boot Logo"
	TASK_PROGRESS 10 100

	TASK_STATUS "Converting for Device"
	TASK_PROGRESS 40 100

	UPDATE_BOOTLOGO

	TASK_STATUS "Writing Boot Logo"
	TASK_PROGRESS 100 100

	ALL_DONE 0 "Completed"
}

[ "$#" -ge 1 ] || USAGE

case "$1" in
	set)
		[ "$#" -eq 3 ] || USAGE
		SET_LOGO "$2" "$3"
		;;
	clear) CLEAR_LOGO ;;
	*) USAGE ;;
esac
