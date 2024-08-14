#!/bin/sh

. /opt/muos/script/var/func.sh

STORE_DEVICE=$(GET_VAR "device" "storage/usb/dev")$(GET_VAR "device" "storage/usb/sep")$(GET_VAR "device" "storage/usb/num")
MOUNTED=false

mkdir "$(GET_VAR "device" "storage/usb/mount")"

while true; do
	if grep -m 1 "$STORE_DEVICE" /proc/partitions >/dev/null; then
		if ! $MOUNTED; then
			FS_TYPE=$(blkid -o value -s TYPE "/dev/$STORE_DEVICE")
			if [ "$FS_TYPE" = "vfat" ]; then
				mount -t vfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "$(GET_VAR "device" "storage/usb/mount")"
				MOUNTED=true
			elif [ "$FS_TYPE" = "exfat" ]; then
				mount -t exfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "$(GET_VAR "device" "storage/usb/mount")"
				MOUNTED=true
			elif [ "$FS_TYPE" = "ext4" ]; then
				mount -t ext4 -o defaults,noatime,nofail "/dev/$STORE_DEVICE" "$(GET_VAR "device" "storage/usb/mount")"
				MOUNTED=true
			fi
			/opt/muos/script/mount/prepare.sh "$(GET_VAR "device" "storage/usb/mount")" &
		fi
	elif $MOUNTED; then
		umount "$(GET_VAR "device" "storage/usb/mount")"
		MOUNTED=false
	fi
	sleep 2
done &
