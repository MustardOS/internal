#!/bin/sh

. /opt/muos/script/var/func.sh

STORE_DEVICE=$(GET_VAR "device" "storage/sdcard/dev")$(GET_VAR "device" "storage/sdcard/sep")$(GET_VAR "device" "storage/sdcard/num")
MOUNTED=false

mkdir "$(GET_VAR "device" "storage/sdcard/mount")"

while true; do
	if grep -m 1 "$STORE_DEVICE" /proc/partitions >/dev/null; then
		if ! $MOUNTED; then
			FS_TYPE=$(blkid -o value -s TYPE "/dev/$STORE_DEVICE")
			if [ "$FS_TYPE" = "vfat" ]; then
				if mount -t vfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "$(GET_VAR "device" "storage/sdcard/mount")"; then
					SET_VAR "device" "storage/sdcard/active" "1"
					echo noop >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/mmc1:0001/block/mmcblk1/queue/scheduler
					echo on >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/power/control
					MOUNTED=true
				fi
			elif [ "$FS_TYPE" = "exfat" ]; then
				if mount -t exfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "$(GET_VAR "device" "storage/sdcard/mount")"; then
					SET_VAR "device" "storage/sdcard/active" "1"
					echo noop >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/mmc1:0001/block/mmcblk1/queue/scheduler
					echo on >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/power/control
					MOUNTED=true
				fi
			elif [ "$FS_TYPE" = "ext4" ]; then
				if mount -t ext4 -o defaults,noatime,nofail "/dev/$STORE_DEVICE" "$(GET_VAR "device" "storage/sdcard/mount")"; then
					SET_VAR "device" "storage/sdcard/active" "1"
					echo noop >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/mmc1:aaaa/block/mmcblk1/queue/scheduler
					echo on >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/power/control
					MOUNTED=true
				fi
			fi
			/opt/muos/script/mount/prepare.sh "$(GET_VAR "device" "storage/sdcard/mount")" &
		fi
	elif $MOUNTED; then
		umount "$(GET_VAR "device" "storage/sdcard/mount")"
		SET_VAR "device" "storage/sdcard/active" "0"
		MOUNTED=false
	fi
	sleep 2
done &
