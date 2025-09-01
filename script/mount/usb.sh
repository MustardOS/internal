#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/sync.sh

FIRST_INIT="$(GET_VAR "config" "boot/first_init")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"

USB_DEV="$(GET_VAR "device" "storage/usb/dev")"
USB_SEP="$(GET_VAR "device" "storage/usb/sep")"
USB_NUM="$(GET_VAR "device" "storage/usb/num")"
USB_MOUNT="$(GET_VAR "device" "storage/usb/mount")"

DEVICE="${USB_DEV}${USB_SEP}${USB_NUM}"

PURGE_MOUNT() {
	[ -d "$USB_MOUNT" ] && rm -rf "$USB_MOUNT"
}

MOUNTED() {
	grep -qs " $USB_MOUNT " /proc/mounts
}

HAS_DEVICE() {
	grep -qw "$DEVICE" /proc/partitions
}

MOUNT_DEVICE() {
	FS_TYPE="$(blkid -o value -s TYPE "/dev/$DEVICE" 2>/dev/null || true)"
	FS_LABEL="$(blkid -o value -s LABEL "/dev/$DEVICE" 2>/dev/null || true)"

	mkdir -p "$USB_MOUNT"

	case "$FS_TYPE" in
		vfat | exfat) FS_OPTS="rw,utf8,noatime,nofail" ;;
		*) return 1 ;;
	esac

	if mount -t "$FS_TYPE" -o "$FS_OPTS" "/dev/$DEVICE" "$USB_MOUNT"; then
		SET_VAR "device" "storage/usb/active" "1"
		SET_VAR "device" "storage/usb/label" "${FS_LABEL:-}"

		KERNEL_TUNING "$USB_DEV"

		mkdir -p "$USB_MOUNT/ROMS" "$USB_MOUNT/BACKUP" "$USB_MOUNT/ARCHIVE" "$USB_MOUNT/ports"

		if [ -d "$USB_MOUNT/MUOS/info/name" ]; then
			SYNC_FILE "$ROM_MOUNT" "$USB_MOUNT" "MUOS/info/name/tag.txt" size "atomic,verify"
			SYNC_FILE "$ROM_MOUNT" "$USB_MOUNT" "MUOS/info/name/folder.json" size "atomic,verify"
			SYNC_FILE "$ROM_MOUNT" "$USB_MOUNT" "MUOS/info/name/global.json" size "atomic,verify"
		fi

		if [ "$FIRST_INIT" -eq 0 ]; then
			# Checking for junk
			DELETE_CRUFT "$USB_MOUNT"

			# Move old MUOS directory
			mv "$USB_MOUNT/MUOS" "$USB_MOUNT/MUOS_old"
		fi

		return 0
	fi

	PURGE_MOUNT

	return 1
}

UNMOUNT_DEVICE() {
	sync || true

	if umount "$USB_MOUNT" 2>/dev/null; then
		SET_VAR "device" "storage/usb/active" "0"
		PURGE_MOUNT

		return 0
	fi

	# Fallback lazy unmount if busy...
	if umount -l "$USB_MOUNT" 2>/dev/null; then
		SET_VAR "device" "storage/usb/active" "0"
		PURGE_MOUNT

		return 0
	fi

	return 1
}

DO_MOUNT() {
	if MOUNTED; then
		printf "USB External storage already mounted\n"

		exit 0
	fi

	if ! HAS_DEVICE; then
		printf "USB External storage device not present: /dev/%s\n" "$DEVICE" >&2

		exit 1
	fi

	/opt/muos/script/mount/union.sh stop

	if MOUNT_DEVICE; then
		/opt/muos/script/mount/bind.sh
		/opt/muos/script/mount/union.sh start

		printf "USB External storage mounted: /dev/%s -> %s\n" "$DEVICE" "$USB_MOUNT"

		exit 0
	fi

	printf "USB External storage mount failed: /dev/%s\n" "$DEVICE" >&2
	SET_VAR "device" "storage/usb/active" "0"

	/opt/muos/script/mount/union.sh start

	exit 1
}

DO_EJECT() {
	if ! MOUNTED; then
		SET_VAR "device" "storage/usb/active" "0"
		printf "USB External storage already unmounted\n"

		exit 0
	fi

	/opt/muos/script/mount/union.sh stop

	if UNMOUNT_DEVICE; then
		/opt/muos/script/mount/bind.sh
		/opt/muos/script/mount/union.sh start

		printf "USB External storage ejected: %s\n" "$USB_MOUNT"

		exit 0
	fi

	/opt/muos/script/mount/union.sh start

	printf "USB External storage eject failed: %s\n" "$USB_MOUNT" >&2

	exit 1
}

DO_DOWN() {
	if ! MOUNTED; then
		SET_VAR "device" "storage/usb/active" "0"
		printf "USB External storage already unmounted\n"

		exit 0
	fi

	if UNMOUNT_DEVICE; then
		printf "USB External storage down: %s\n" "$USB_MOUNT"

		exit 0
	fi

	printf "USB External storage down failed: %s\n" "$USB_MOUNT" >&2
	SET_VAR "device" "storage/usb/active" "0"

	exit 1
}

DO_STATUS() {
	if MOUNTED; then
		printf "USB External storage mounted\n"

		exit 0
	fi

	printf "USB External storage not mounted\n"

	exit 1
}

USAGE() {
	printf "Usage: %s {mount|eject|down|status}\n" "$0" >&2

	exit 2
}

case "${1-}" in
	mount) DO_MOUNT ;;
	eject) DO_EJECT ;;
	down) DO_DOWN ;;
	status) DO_STATUS ;;
	*) USAGE ;;
esac
