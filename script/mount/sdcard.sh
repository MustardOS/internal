#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE="$(GET_VAR "device" "storage/sdcard/dev")$(GET_VAR "device" "storage/sdcard/sep")$(GET_VAR "device" "storage/sdcard/num")"
MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"

mkdir -p "$MOUNT"

MOUNTED () {
	[ "$(GET_VAR "device" "storage/sdcard/active")" -eq 1 ]
}

HAS_DEVICE() {
	grep -q "$DEVICE" /proc/partitions
}

MOUNT_DEVICE() {
	FS_TYPE="$(blkid -o value -s TYPE "/dev/$DEVICE")"

	BLK_ID4=""
	for D in /sys/devices/platform/soc/sdc0/mmc_host/mmc0/mmc0:*; do
		[ -d "$D" ] && BLK_ID4="${D##*/}" && break
	done

	case "$FS_TYPE" in
		vfat|exfat) FS_OPTS=rw,utf8,noatime,nofail ;;
		ext4) FS_OPTS=defaults,noatime,nofail ;;
		*) return ;;
	esac

	if mount -t "$FS_TYPE" -o "$FS_OPTS" "/dev/$DEVICE" "$MOUNT"; then
		SET_VAR "device" "storage/sdcard/active" "1"
		echo noop >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/mmc1:"$BLK_ID4"/block/mmcblk1/queue/scheduler
		echo on >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/power/control
	fi
}

# Synchronously mount SD card (if media is inserted) so it's available as a
# target of bind mounts under /run/muos/storage as soon as this script returns.
HAS_DEVICE && MOUNT_DEVICE

# Asynchronously monitor insertion/eject, adjusting storage mounts as needed.
while true; do
	sleep 2
	if HAS_DEVICE; then
		if ! MOUNTED; then
			MOUNT_DEVICE
			/opt/muos/script/var/init/storage.sh
		fi
	elif MOUNTED; then
		umount "$MOUNT"
		SET_VAR "device" "storage/sdcard/active" "0"
		/opt/muos/script/var/init/storage.sh
	fi
done &
