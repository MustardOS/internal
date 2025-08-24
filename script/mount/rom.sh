#!/bin/sh

. /opt/muos/script/var/func.sh

FIRST_INIT=$(GET_VAR "config" "boot/first_init")

ROM_DEV="$(GET_VAR "device" "storage/rom/dev")"
ROM_SEP="$(GET_VAR "device" "storage/rom/sep")"
ROM_NUM="$(GET_VAR "device" "storage/rom/num")"
ROM_TYPE="$(GET_VAR "device" "storage/rom/type")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"
CARD_MODE="$(GET_VAR "config" "danger/cardmode")"

DEVICE="${ROM_DEV}${ROM_SEP}${ROM_NUM}"
mkdir -p "$ROM_MOUNT"

if mount -t "$ROM_TYPE" -o rw,utf8,noatime,nofail "/dev/$DEVICE" "$ROM_MOUNT"; then
	SET_VAR "device" "storage/rom/active" "1"
	SET_VAR "device" "storage/rom/label" "$(blkid -o value -s LABEL "/dev/$DEVICE")"
fi

if [ "$CARD_MODE" = "noop" ]; then
	echo "noop" >"/sys/block/$ROM_DEV/queue/scheduler"
	echo "write back" >"/sys/block/$ROM_DEV/queue/write_cache"
else
	echo "deadline" >"/sys/block/$ROM_DEV/queue/scheduler"
	echo "write through" >"/sys/block/$ROM_DEV/queue/write_cache"
fi

KERNEL_TUNING "$ROM_DEV"

# Ensure ROMS directory exists
mkdir -p "$ROM_MOUNT/ROMS" "$ROM_MOUNT/BACKUP" "$ROM_MOUNT/ARCHIVE" "$ROM_MOUNT/ports"

# Checking for junk
[ "$FIRST_INIT" -eq 0 ] && DELETE_CRUFT "$ROM_MOUNT"
