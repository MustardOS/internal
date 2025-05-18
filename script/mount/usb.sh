#!/bin/sh

. /opt/muos/script/var/func.sh

USB_DEV="$(GET_VAR "device" "storage/usb/dev")"
USB_SEP="$(GET_VAR "device" "storage/usb/sep")"
USB_NUM="$(GET_VAR "device" "storage/usb/num")"
USB_MOUNT="$(GET_VAR "device" "storage/usb/mount")"

DEVICE="${USB_DEV}${USB_SEP}${USB_NUM}"
mkdir -p "$USB_MOUNT"

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
		ext4) FS_OPTS=rw,noatime,nofail ;;
		*) return ;;
	esac

	if mount -t "$FS_TYPE" -o "$FS_OPTS" "/dev/$DEVICE" "$USB_MOUNT"; then
		SET_VAR "device" "storage/usb/active" "1"
		SET_VAR "device" "storage/usb/label" "$FS_LABEL"
	fi

	mkdir -p "$USB_MOUNT/ROMS" "$USB_MOUNT/BACKUP" "$USB_MOUNT/ARCHIVE" "$USB_MOUNT/ports"
}

# Asynchronously monitor insertion/eject
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
		umount "$USB_MOUNT"
		SET_VAR "device" "storage/usb/active" "0"
		/opt/muos/script/mount/bind.sh
		/opt/muos/script/mount/union.sh start
	fi

	sleep 2
done &
