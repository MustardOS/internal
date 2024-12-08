#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE="$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")"
MOUNT="$(GET_VAR "device" "storage/rom/mount")"

mkdir -p "$MOUNT"

if mount -t "$(GET_VAR "device" "storage/rom/type")" -o rw,utf8,noatime,nofail "/dev/$DEVICE" "$MOUNT"; then
	SET_VAR "device" "storage/rom/active" "1"
	SET_VAR "device" "storage/rom/label" "$(blkid -o value -s LABEL "/dev/$DEVICE")"
fi

if [ "$(GET_VAR "global" "settings/advanced/cardmode")" = "noop" ]; then
	echo "noop" >"/sys/block/$(GET_VAR "device" "storage/rom/dev")/queue/scheduler"
	echo "write back" >"/sys/block/$(GET_VAR "device" "storage/rom/dev")/queue/write_cache"
else
	echo "deadline" >"/sys/block/$(GET_VAR "device" "storage/rom/dev")/queue/scheduler"
	echo "write through" >"/sys/block/$(GET_VAR "device" "storage/rom/dev")/queue/write_cache"
fi

# Create ROMS directory if it doesn't exist
[ ! -d "$MOUNT/ROMS" ] && mkdir -p "$MOUNT/ROMS"
