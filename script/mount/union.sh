#!/bin/sh

. /opt/muos/script/var/func.sh

READ_WRITE_TYPE="RW"

ROM_SUBDIR="ROMS"
ROM_TARGET="/mnt/union/$ROM_SUBDIR"

PORT_SUBDIR="PORTS"
PORT_TARGET="/mnt/union/$PORT_SUBDIR"

UFS_BIN="/opt/muos/bin/ufs/unionfs"

USB_MOUNT=$(GET_VAR "device" "storage/usb/mount")
SDCARD_MOUNT=$(GET_VAR "device" "storage/sdcard/mount")
ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")

CHECK_MOUNT() {
	grep -q " $1 " /proc/mounts
}

UNION_VALIDATION() {
	command -v "$UFS_BIN" >/dev/null 2>&1 || {
		LOG_ERROR "$0" 0 "UNIONFS" "Required binary $UFS_BIN not found"
		exit 1
	}

	if [ -n "$USB_MOUNT" ] && ! CHECK_MOUNT "$USB_MOUNT"; then
		LOG_WARN "$0" 0 "UNIONFS" "USB is not mounted, skipping!"
		USB_MOUNT=""
	fi

	if [ -n "$SDCARD_MOUNT" ] && ! CHECK_MOUNT "$SDCARD_MOUNT"; then
		LOG_WARN "$0" 0 "UNIONFS" "SDCARD is not mounted, skipping!"
		SDCARD_MOUNT=""
	fi

	if [ -n "$ROM_MOUNT" ] && ! CHECK_MOUNT "$ROM_MOUNT"; then
		LOG_ERROR "$0" 0 "UNIONFS" "ROM is not mounted... uh oh!"
		exit 1
	fi
}

UNION_PATH_CREATE() {
	if ! mkdir -p "$ROM_TARGET" "$PORT_TARGET"; then
		LOG_ERROR "$0" 0 "UNIONFS" "Failed to create target directories: $ROM_TARGET, $PORT_TARGET"
		exit 1
	fi
}

BUILD_UNION() {
	for STORAGE_POINT in "$USB_MOUNT" "$SDCARD_MOUNT" "$ROM_MOUNT"; do
		[ -n "$STORAGE_POINT" ] || continue

		UNION_PATH="$STORAGE_POINT/$1"
		[ -d "$UNION_PATH" ] && printf "%s=$READ_WRITE_TYPE:" "$UNION_PATH"
	done | sed 's|:$||'
}

START_UNION() {
	for SOURCE in "$ROM_SUBDIR" "$PORT_SUBDIR"; do
		UNION_SOURCES=$(BUILD_UNION "$SOURCE")

		if [ -z "$UNION_SOURCES" ]; then
			LOG_ERROR "$0" 0 "UNIONFS" "No valid $SOURCE directory found"
			continue
		fi

		TARGET="$ROM_TARGET"
		[ "$SOURCE" = "$PORT_SUBDIR" ] && TARGET="$PORT_TARGET"

		if [ -n "$TARGET" ] && "$UFS_BIN" "$UNION_SOURCES" "$TARGET"; then
			LOG_INFO "$0" 0 "UNIONFS" "Union mount for $SOURCE started successfully at $TARGET"
		else
			LOG_ERROR "$0" 0 "UNIONFS" "Failed to start union mount for $SOURCE at $TARGET"
		fi
	done
}

STOP_UNION() {
	for TARGET in "$ROM_TARGET" "$PORT_TARGET"; do
		if mountpoint -q "$TARGET"; then
			if umount "$TARGET"; then
				LOG_INFO "$0" 0 "UNIONFS" "Union mount at $TARGET stopped successfully"
			else
				LOG_ERROR "$0" 0 "UNIONFS" "Failed to stop union mount at $TARGET"
			fi
		fi
	done
}

RESTART_UNION() {
	STOP_UNION
	START_UNION
}

SHOW_USAGE() {
	INVALID_MSG=$(printf "Invalid argument: %s" "$1")
	EXPECT_MSG=$(printf "Usage: %s {start|stop|restart}" "$(basename "$0")")

	LOG_ERROR "$0" 0 "UNIONFS" "$INVALID_MSG - $EXPECT_MSG"
	printf "%s - %s\n" "$INVALID_MSG" "$EXPECT_MSG"
	exit 2
}

UNION_VALIDATION
UNION_PATH_CREATE

case "$1" in
	start) START_UNION ;;
	stop) STOP_UNION ;;
	restart) RESTART_UNION ;;
	*) SHOW_USAGE "$1" ;;
esac
