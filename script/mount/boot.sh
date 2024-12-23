#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE="$(GET_VAR "device" "storage/boot/dev")$(GET_VAR "device" "storage/boot/sep")$(GET_VAR "device" "storage/boot/num")"
MOUNT="$(GET_VAR "device" "storage/boot/mount")"

if mount -t "$(GET_VAR "device" "storage/boot/type")" -o rw,utf8,noatime,nofail "/dev/$DEVICE" "$MOUNT"; then
	SET_VAR "device" "storage/boot/active" "1"
	SET_VAR "device" "storage/boot/label" "$(blkid -o value -s LABEL "/dev/$DEVICE")"
fi
