#!/bin/sh

. /opt/muos/script/var/func.sh

READ_WRITE_TYPE="RO"
ROM_SUBDIR="ROMS"
UNION_MOUNT_POINT="/mnt/union"
UNION_TARGET="$UNION_MOUNT_POINT/$ROM_SUBDIR"
UFS_BIN="/opt/muos/bin/ufs/unionfs"

mkdir -p "$UNION_MOUNT_POINT"

BUILD_UNION() {
	for STORAGE_POINT in \
		"$(GET_VAR "device" "storage/usb/mount")" \
		"$(GET_VAR "device" "storage/sdcard/mount")" \
		"$(GET_VAR "device" "storage/rom/mount")"; do
		UNION_PATH="$STORAGE_POINT/$ROM_SUBDIR"
		[ -d "$UNION_PATH" ] && printf "%s=$READ_WRITE_TYPE:" "$UNION_PATH"
	done | sed 's/:$//'
}

START_UNION() {
	UNION_SOURCES=$(BUILD_UNION)
	if [ -z "$UNION_SOURCES" ]; then
		LOG_ERROR "$0" 0 "UNIONFS" "No valid ROM directories found"
		exit 1
	fi

	if "$UFS_BIN" "$UNION_SOURCES" "$UNION_TARGET"; then
		LOG_INFO "$0" 0 "UNIONFS" "Union mount started successfully"
	else
		LOG_ERROR "$0" 0 "UNIONFS" "Failed to start union mount"
		exit 1
	fi
}

STOP_UNION() {
	if umount "$UNION_TARGET"; then
		LOG_INFO "$0" 0 "UNIONFS" "Union mount stopped successfully"
	else
		LOG_ERROR "$0" 0 "UNIONFS" "Failed to stop union mount"
		exit 1
	fi
}

RESTART_UNION() {
	STOP_UNION
	START_UNION
}

SHOW_USAGE() {
	printf "Usage: %s {start|stop|restart}\n" "$(basename "$0")"
	exit 2
}

case "$1" in
	start) START_UNION ;;
	stop) STOP_UNION ;;
	restart) RESTART_UNION ;;
	*) SHOW_USAGE ;;
esac
