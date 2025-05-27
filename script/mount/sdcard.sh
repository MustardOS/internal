#!/bin/sh

. /opt/muos/script/var/func.sh

SD_DEV="$(GET_VAR "device" "storage/sdcard/dev")"
SD_SEP="$(GET_VAR "device" "storage/sdcard/sep")"
SD_NUM="$(GET_VAR "device" "storage/sdcard/num")"
SD_MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
CARD_MODE="$(GET_VAR "global" "settings/advanced/cardmode")"

DEVICE="${SD_DEV}${SD_SEP}${SD_NUM}"
mkdir -p "$SD_MOUNT"

MOUNTED() {
	[ "$(GET_VAR "device" "storage/sdcard/active")" -eq 1 ]
}

HAS_DEVICE() {
	grep -q "$DEVICE" /proc/partitions
}

MOUNT_DEVICE() {
	FS_TYPE="$(blkid -o value -s TYPE "/dev/$DEVICE")"
	FS_LABEL="$(blkid -o value -s LABEL "/dev/$DEVICE")"

	case "$FS_TYPE" in
		vfat | exfat) FS_OPTS=rw,utf8,noatime,nofail ;;
		*) return ;;
	esac

	if mount -t "$FS_TYPE" -o "$FS_OPTS" "/dev/$DEVICE" "$SD_MOUNT"; then
		SET_VAR "device" "storage/sdcard/active" "1"
		SET_VAR "device" "storage/sdcard/label" "$FS_LABEL"
	fi

	if [ "$CARD_MODE" = "noop" ]; then
		echo "noop" >"/sys/block/$SD_DEV/queue/scheduler"
		echo "write back" >"/sys/block/$SD_DEV/queue/write_cache"
	else
		echo "deadline" >"/sys/block/$SD_DEV/queue/scheduler"
		echo "write through" >"/sys/block/$SD_DEV/queue/write_cache"
	fi

	echo 8 >/proc/sys/vm/swappiness
	echo 16 >/proc/sys/vm/dirty_ratio
	echo 4 >/proc/sys/vm/dirty_background_ratio
	echo 64 >/proc/sys/vm/vfs_cache_pressure

	echo 2 >"/sys/block/$SD_DEV/queue/nomerges"
	echo 128 >"/sys/block/$SD_DEV/queue/nr_requests"
	echo 0 >"/sys/block/$SD_DEV/queue/iostats"
	blockdev --setra 4096 "/dev/$SD_DEV"

	mkdir -p "$SD_MOUNT/ROMS" "$SD_MOUNT/BACKUP" "$SD_MOUNT/ARCHIVE" "$SD_MOUNT/ports"
}

# Synchronously mount SD card (if media is inserted) so it's available as a
# target of bind mounts under /run/muos/storage as soon as this script returns
HAS_DEVICE && MOUNT_DEVICE

# Asynchronously monitor insertion/eject, adjusting storage mounts as needed
while :; do
	if HAS_DEVICE; then
		if ! MOUNTED; then
			/opt/muos/script/mount/union.sh stop
			MOUNT_DEVICE
			/opt/muos/script/mount/bind.sh
			/opt/muos/script/mount/union.sh start
		fi
	elif MOUNTED; then
		/opt/muos/script/mount/union.sh stop
		umount "$SD_MOUNT"
		SET_VAR "device" "storage/sdcard/active" "0"
		/opt/muos/script/mount/bind.sh
		/opt/muos/script/mount/union.sh start
	fi

	/opt/muos/bin/toybox sleep 2
done &
