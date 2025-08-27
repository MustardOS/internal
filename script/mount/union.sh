#!/bin/sh

. /opt/muos/script/var/func.sh

READ_WRITE_TYPE="RW"

ROM_SUBDIR="ROMS"
ROM_TARGET="/mnt/union/$ROM_SUBDIR"

PORT_SUBDIR="ports"
PORT_TARGET="/mnt/union/$PORT_SUBDIR"

UFS_BIN="/opt/muos/bin/ufs/unionfs"
UFS_OPTS="cow" # Moo!

USB_MOUNT=$(GET_VAR "device" "storage/usb/mount")
SDCARD_MOUNT=$(GET_VAR "device" "storage/sdcard/mount")
ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")

CHECK_MOUNT() {
	grep -qs " $1 " /proc/mounts
}

UFS_MOUNTED() {
	grep -qs " $1 fuse.unionfs " /proc/mounts
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
		[ -d "$UNION_PATH" ] && printf "%s=%s:" "$UNION_PATH" "$READ_WRITE_TYPE"
	done | sed 's|:$||'
}

START_ONE() {
	SOURCE="$1"
	TARGET="$2"

	# This is already mounted so... nothing to do!
	if UFS_MOUNTED "$TARGET"; then
		LOG_INFO "$0" 0 "UNIONFS" "Union for $SOURCE already active at $TARGET"
		return 0
	fi

	UNION_SOURCES=$(BUILD_UNION "$SOURCE")
	if [ -z "$UNION_SOURCES" ]; then
		LOG_ERROR "$0" 0 "UNIONFS" "No valid $SOURCE directory found"
		return 1
	fi

	if "$UFS_BIN" -o "$UFS_OPTS" "$UNION_SOURCES" "$TARGET"; then
		if UFS_MOUNTED "$TARGET"; then
			LOG_INFO "$0" 0 "UNIONFS" "Union mount for $SOURCE started at $TARGET"
			return 0
		fi
	fi

	LOG_ERROR "$0" 0 "UNIONFS" "Failed to start union mount for $SOURCE at $TARGET"
	return 1
}

STOP_ONE() {
	TARGET="$1"
	UFS_MOUNTED "$TARGET" || return 0

	umount "$TARGET" 2>/dev/null || umount -l "$TARGET" 2>/dev/null || true

	# If anything stubborn is left, kill by target path!
	if UFS_MOUNTED "$TARGET"; then
		pkill -f "^$UFS_BIN .* $TARGET\$" 2>/dev/null || true
	fi

	if UFS_MOUNTED "$TARGET"; then
		LOG_ERROR "$0" 0 "UNIONFS" "Failed to stop union at $TARGET"
		return 1
	fi

	LOG_INFO "$0" 0 "UNIONFS" "Union at $TARGET stopped"
	return 0
}

START_UNION() {
	START_ONE "$ROM_SUBDIR" "$ROM_TARGET"
	START_ONE "$PORT_SUBDIR" "$PORT_TARGET"
}

STOP_UNION() {
	STOP_ONE "$PORT_TARGET"
	STOP_ONE "$ROM_TARGET"
}

RESTART_UNION() {
	STOP_UNION
	START_UNION
}

USAGE() {
	INVALID_MSG=$(printf "Invalid argument: %s" "$1")
	EXPECT_MSG=$(printf "Usage: %s {start|stop|restart}" "$(basename "$0")")

	LOG_ERROR "$0" 0 "UNIONFS" "$INVALID_MSG - $EXPECT_MSG"
	printf "%s - %s\n" "$INVALID_MSG" "$EXPECT_MSG"

	exit 2
}

UNION_VALIDATION
UNION_PATH_CREATE

case "${1-}" in
	start) START_UNION ;;
	stop) STOP_UNION ;;
	restart) RESTART_UNION ;;
	*) USAGE "$1" ;;
esac
