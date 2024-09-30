#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE="$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")"
MOUNT="$(GET_VAR "device" "storage/rom/mount")"

if mount -t "$(GET_VAR "device" "storage/rom/type")" -o rw,utf8,noatime,nofail "$DEVICE" "$MOUNT"; then
	SET_VAR "device" "storage/rom/active" "1"
	SET_VAR "device" "storage/rom/label" "$(blkid -o value -s LABEL "/dev/$DEVICE")"
fi
