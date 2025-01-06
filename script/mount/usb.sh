#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE=$(GET_VAR "device" "storage/usb/dev")$(GET_VAR "device" "storage/usb/sep")$(GET_VAR "device" "storage/usb/num")
MOUNT="$(GET_VAR "device" "storage/usb/mount")"

mkdir -p "$MOUNT"

MOUNTED() {
	[ "$(GET_VAR "device" "storage/usb/active")" -eq 1 ]
}

HAS_DEVICE() {
	grep -q "$DEVICE" /proc/partitions
}

MOUNT_DEVICE() {
	FS_TYPE="$(blkid -o value -s TYPE "/dev/$DEVICE")"
	FS_LABEL="$(blkid -o value -s LABEL "/dev/$DEVICE")"

	case "$FS_TYPE" in
		vfat | exfat) FS_OPTS=rw,utf8,noatime,nofail ;;
		ext4) FS_OPTS=defaults,noatime,nofail ;;
		*) return ;;
	esac

	if mount -t "$FS_TYPE" -o "$FS_OPTS" "/dev/$DEVICE" "$MOUNT"; then
		SET_VAR "device" "storage/usb/active" "1"
		SET_VAR "device" "storage/usb/label" "$FS_LABEL"
	fi

	if [ "$(GET_VAR "global" "settings/advanced/cardmode")" = "noop" ]; then
		echo "noop" >"/sys/block/$(GET_VAR "device" "storage/usb/dev")/queue/scheduler"
		echo "write back" >"/sys/block/$(GET_VAR "device" "storage/usb/dev")/queue/write_cache"
	else
		echo "deadline" >"/sys/block/$(GET_VAR "device" "storage/usb/dev")/queue/scheduler"
		echo "write through" >"/sys/block/$(GET_VAR "device" "storage/usb/dev")/queue/write_cache"
	fi
}

# Asynchronously monitor insertion/eject
while :; do
	# Create ROMS directory if it doesn't exist because the union calls for it
	[ ! -d "$MOUNT/ROMS" ] && mkdir -p "$MOUNT/ROMS"

	if HAS_DEVICE; then
		! MOUNTED && MOUNT_DEVICE
	elif MOUNTED; then
		umount "$MOUNT"
		SET_VAR "device" "storage/usb/active" "0"
	fi

	sleep 2
done &
