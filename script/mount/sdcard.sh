#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

STORE_DEVICE=${DC_STO_SDCARD_DEV}p${DC_STO_SDCARD_NUM}
MOUNTED=false

mkdir "$DC_STO_SDCARD_MOUNT"

while true; do
	if grep -m 1 "$STORE_DEVICE" /proc/partitions >/dev/null; then
		if ! $MOUNTED; then
			FS_TYPE=$(blkid -o value -s TYPE "/dev/$STORE_DEVICE")
			if [ "$FS_TYPE" = "vfat" ]; then
				mount -t vfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "$DC_STO_SDCARD_MOUNT"
				echo noop >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/mmc1:0001/block/mmcblk1/queue/scheduler
				echo on >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/power/control
				MOUNTED=true
			elif [ "$FS_TYPE" = "exfat" ]; then
				mount -t exfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "$DC_STO_SDCARD_MOUNT"
				echo noop >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/mmc1:0001/block/mmcblk1/queue/scheduler
				echo on >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/power/control
				MOUNTED=true
			elif [ "$FS_TYPE" = "ext4" ]; then
				mount -t ext4 -o defaults,noatime,nofail "/dev/$STORE_DEVICE" "$DC_STO_SDCARD_MOUNT"
				echo noop >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/mmc1:aaaa/block/mmcblk1/queue/scheduler
				echo on >/sys/devices/platform/soc/sdc2/mmc_host/mmc1/power/control
				MOUNTED=true
			fi
			/opt/muos/script/system/dotclean.sh &
		fi
	elif $MOUNTED; then
		umount "$DC_STO_SDCARD_MOUNT"
		MOUNTED=false
	fi
	sleep 2
done &
