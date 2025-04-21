#!/bin/sh

. /opt/muos/script/var/func.sh

BOOT_DEV="$(GET_VAR "device" "storage/boot/dev")"
BOOT_SEP="$(GET_VAR "device" "storage/boot/sep")"
BOOT_NUM="$(GET_VAR "device" "storage/boot/num")"
BOOT_TYPE="$(GET_VAR "device" "storage/boot/type")"
BOOT_MOUNT="$(GET_VAR "device" "storage/boot/mount")"

DEVICE="${BOOT_DEV}${BOOT_SEP}${BOOT_NUM}"

if mount -t "$BOOT_TYPE" -o rw,utf8,noatime,nofail "/dev/$DEVICE" "$BOOT_MOUNT"; then
	SET_VAR "device" "storage/boot/active" "1"
	SET_VAR "device" "storage/boot/label" "$(blkid -o value -s LABEL "/dev/$DEVICE")"
fi
