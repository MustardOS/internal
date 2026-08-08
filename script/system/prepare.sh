#!/bin/sh
# NEVER_CANCEL: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_IS_NATIVE || FRONTEND stop

COMMAND=$(basename "$0")

USAGE() {
	TASK_ERROR "bad_arguments" "$(printf "Usage: %s <sdcard|usb> <vfat|exfat|ext2|ext3|ext4>" "$COMMAND")"
	TASK_IS_NATIVE || FRONTEND start space
	exit 1
}

ALL_DONE() {
	TASK_COMPLETE "$2"
	TASK_IS_NATIVE || FRONTEND start space
	exit "$1"
}

REFUSE() {
	TASK_ERROR "$1" "$2"
	ALL_DONE 1 "Nothing was changed"
}

ABANDON() {
	TASK_ERROR "$1" "$2"
	ALL_DONE 1 "The storage is now empty and needs preparing again"
}

STORAGE="$1"
FSTYPE="$2"

[ -n "$STORAGE" ] || USAGE
[ -n "$FSTYPE" ] || USAGE

case "$STORAGE" in
	sdcard | usb) ;;
	*) REFUSE "protected_storage" "$(printf "'%s' cannot be prepared" "$STORAGE")" ;;
esac

case "$FSTYPE" in
	vfat | exfat | ext2 | ext3 | ext4) ;;
	*) USAGE ;;
esac

FS_CAN_MAKE "$FSTYPE" || REFUSE "no_tooling" "$(printf "This device cannot create %s filesystems" "$FSTYPE")"

DEV="$(GET_VAR "device" "storage/$STORAGE/dev")"
SEP="$(GET_VAR "device" "storage/$STORAGE/sep")"
MOUNT="$(GET_VAR "device" "storage/$STORAGE/mount")"

[ -n "$DEV" ] || REFUSE "no_device" "No device is recorded for that storage"
[ -b "/dev/$DEV" ] || REFUSE "no_device" "$(printf "/dev/%s is not a block device" "$DEV")"

ROOT_DEV="$(GET_VAR "device" "storage/root/dev")"
ROM_DEV="$(GET_VAR "device" "storage/rom/dev")"
BOOT_DEV="$(GET_VAR "device" "storage/boot/dev")"

for GUARD in "$ROOT_DEV" "$ROM_DEV" "$BOOT_DEV"; do
	[ -n "$GUARD" ] || continue
	[ "$DEV" = "$GUARD" ] && REFUSE "system_storage" "That storage is in use by the system"
done

PART="/dev/${DEV}${SEP}1"

case "$STORAGE" in
	sdcard) LABEL="SDCARD" ;;
	usb) LABEL="USB" ;;
esac

LOG_INFO "$0" 0 "PREPARE STORAGE" "Preparing $STORAGE (/dev/$DEV) as $FSTYPE"

TASK_STATUS "Unmounting Storage"
TASK_DETAIL "$MOUNT"
TASK_PROGRESS 10 100

/opt/muos/script/device/storage.sh "$STORAGE" down

awk -v d="/dev/$DEV" '$1 ~ "^"d {print $2}' /proc/mounts | while IFS= read -r OPEN; do
	umount "$OPEN" 2>/dev/null || umount -l "$OPEN" 2>/dev/null
done

TASK_STATUS "Writing Partition Table"
TASK_PROGRESS 35 100

case "$FSTYPE" in
	ext4 | ext3 | ext2) PART_TYPE="83" ;;
	*) PART_TYPE="c" ;;
esac

printf 'label: dos\n,,%s\n' "$PART_TYPE" |
	sfdisk --quiet --wipe always --wipe-partitions always "/dev/$DEV" ||
	ABANDON "partition_failed" "Could not write a new partition table"

sync
sleep 1

[ -b "$PART" ] || ABANDON "partition_failed" "$(printf "%s did not appear" "$PART")"

TASK_STATUS "Formatting Storage"
TASK_DETAIL "$FSTYPE"
TASK_PROGRESS 65 100

MAKE_FILESYSTEM "$FSTYPE" "$PART" "$LABEL" ||
	ABANDON "format_failed" "$(printf "Could not format as %s" "$FSTYPE")"

TASK_STATUS "Mounting Storage"
TASK_PROGRESS 85 100

SET_VAR "device" "storage/$STORAGE/num" "1"
SET_VAR "device" "storage/$STORAGE/type" "$FSTYPE"

/opt/muos/script/device/storage.sh "$STORAGE" mount || ALL_DONE 1 "$(printf "Formatted, but %s could not be mounted" "$STORAGE")"

TASK_STATUS "Syncing Storage"
TASK_PROGRESS 95 100

sync

LOG_INFO "$0" 0 "PREPARE STORAGE" "Prepared $STORAGE as $FSTYPE"

TASK_PROGRESS 100 100
ALL_DONE 0 "Completed"
