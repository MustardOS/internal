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
				if mount -t vfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "$(GET_VAR "device" "storage/usb/mount")"; then
					SET_VAR "device" "storage/usb/active" "1"
					MOUNTED=true
				fi
			elif [ "$FS_TYPE" = "exfat" ]; then
				if mount -t exfat -o rw,utf8,noatime,nofail "/dev/$STORE_DEVICE" "$(GET_VAR "device" "storage/usb/mount")"; then
					SET_VAR "device" "storage/usb/active" "1"
					MOUNTED=true
				fi
			elif [ "$FS_TYPE" = "ext4" ]; then
				if mount -t ext4 -o defaults,noatime,nofail "/dev/$STORE_DEVICE" "$(GET_VAR "device" "storage/usb/mount")"; then
					SET_VAR "device" "storage/usb/active" "1"
					MOUNTED=true
				fi
			fi
		fi
	elif $MOUNTED; then
		umount "$(GET_VAR "device" "storage/usb/mount")"
		SET_VAR "device" "storage/usb/active" "0"
		MOUNTED=false
	fi
	sleep 2
done &
