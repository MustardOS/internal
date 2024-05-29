#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_DEVICE=$(parse_ini "$DEVICE_CONFIG" "storage.usb" "dev")$(parse_ini "$DEVICE_CONFIG" "storage.usb" "num")
MOUNT_POINT=$(parse_ini "$DEVICE_CONFIG" "storage.usb" "mount")
MOUNTED=false

mkdir "/$MOUNT_POINT"

while true; do
	if grep -m 1 "$STORE_DEVICE" /proc/partitions > /dev/null; then
		if ! $MOUNTED; then
			FS_TYPE=$(blkid -o value -s TYPE "/dev/$STORE_DEVICE")
			if [ "$FS_TYPE" = "vfat" ]; then
				mount -t vfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "/$MOUNT_POINT"
				MOUNTED=true
			elif [ "$FS_TYPE" = "exfat" ]; then
				mount -t exfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "/$MOUNT_POINT"
				MOUNTED=true
			elif [ "$FS_TYPE" = "ext4" ]; then
				mount -t ext4 -o defaults,noatime,nofail "/dev/$STORE_DEVICE" "/$MOUNT_POINT"
				MOUNTED=true
			fi
		fi
	elif $MOUNTED; then
		umount "/$MOUNT_POINT"
		MOUNTED=false
	fi
	sleep 2
done &

