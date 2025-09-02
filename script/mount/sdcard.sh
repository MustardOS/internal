#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/sync.sh

FIRST_INIT="$(GET_VAR "config" "boot/first_init")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"

SD_DEV="$(GET_VAR "device" "storage/sdcard/dev")"
SD_SEP="$(GET_VAR "device" "storage/sdcard/sep")"
SD_NUM="$(GET_VAR "device" "storage/sdcard/num")"
SD_MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"

CARD_MODE="$(GET_VAR "config" "danger/cardmode")"

DEVICE="${SD_DEV}${SD_SEP}${SD_NUM}"

PURGE_MOUNT() {
	[ -d "$SD_MOUNT" ] && rm -rf "$SD_MOUNT"
}

MOUNTED() {
	grep -qs " $SD_MOUNT " /proc/mounts
}

HAS_DEVICE() {
	grep -qw "$DEVICE" /proc/partitions
}

MOUNT_DEVICE() {
	FS_TYPE="$(blkid -o value -s TYPE "/dev/$DEVICE" 2>/dev/null || true)"
	FS_LABEL="$(blkid -o value -s LABEL "/dev/$DEVICE" 2>/dev/null || true)"

	case "$FS_TYPE" in
		vfat | exfat) FS_OPTS="rw,utf8,noatime,nofail" ;;
		*) return 1 ;;
	esac

	mkdir -p "$SD_MOUNT"

	if mount -t "$FS_TYPE" -o "$FS_OPTS" "/dev/$DEVICE" "$SD_MOUNT"; then
		SET_VAR "device" "storage/sdcard/active" "1"
		SET_VAR "device" "storage/sdcard/label" "${FS_LABEL:-}"

		if [ "$CARD_MODE" = "noop" ]; then
			echo "noop" >"/sys/block/$SD_DEV/queue/scheduler" 2>/dev/null || true
			echo "write back" >"/sys/block/$SD_DEV/queue/write_cache" 2>/dev/null || true
		else
			echo "deadline" >"/sys/block/$SD_DEV/queue/scheduler" 2>/dev/null || true
			echo "write through" >"/sys/block/$SD_DEV/queue/write_cache" 2>/dev/null || true
		fi

		KERNEL_TUNING "$SD_DEV"

		mkdir -p "$SD_MOUNT/ROMS" "$SD_MOUNT/BACKUP" "$SD_MOUNT/ARCHIVE" "$SD_MOUNT/ports"

		if [ -d "$SD_MOUNT/MUOS/info/name" ]; then
			SYNC_FILE "$ROM_MOUNT" "$SD_MOUNT" "MUOS/info/name/tag.txt" size "atomic,verify"
			SYNC_FILE "$ROM_MOUNT" "$SD_MOUNT" "MUOS/info/name/folder.json" size "atomic,verify"
			SYNC_FILE "$ROM_MOUNT" "$SD_MOUNT" "MUOS/info/name/global.json" size "atomic,verify"
		fi

		if [ "$FIRST_INIT" -eq 0 ]; then
			# Checking for junk
			DELETE_CRUFT "$SD_MOUNT"

			# Move old MUOS directory
			SRC="$SD_MOUNT/MUOS"
			if [ -d "$SRC" ]; then
				BASE="$SD_MOUNT/MUOS_old"
				DEST="$BASE"

				N=0
				while [ -d "$DEST" ]; do
					N=$((N + 1))
					DEST="${BASE}_$N"
				done

				mv "$SRC" "$DEST"
			fi
		fi

		return 0
	fi

	PURGE_MOUNT

	return 1
}

UNMOUNT_DEVICE() {
	sync || true

	if umount "$SD_MOUNT" 2>/dev/null; then
		SET_VAR "device" "storage/sdcard/active" "0"
		PURGE_MOUNT

		return 0
	fi

	# Fallback lazy unmount if busy...
	if umount -l "$SD_MOUNT" 2>/dev/null; then
		SET_VAR "device" "storage/sdcard/active" "0"
		PURGE_MOUNT

		return 0
	fi

	return 1
}

DO_MOUNT() {
	if MOUNTED; then
		printf "Secondary storage already mounted\n"

		exit 0
	fi

	if ! HAS_DEVICE; then
		printf "Secondary storage device not present: /dev/%s\n" "$DEVICE" >&2

		exit 1
	fi

	/opt/muos/script/mount/union.sh stop

	if MOUNT_DEVICE; then
		/opt/muos/script/mount/bind.sh
		/opt/muos/script/mount/union.sh start

		printf "Secondary storage mounted: /dev/%s -> %s\n" "$DEVICE" "$SD_MOUNT"

		exit 0
	fi

	printf "Secondary storage mount failed: /dev/%s\n" "$DEVICE" >&2
	SET_VAR "device" "storage/sdcard/active" "0"

	/opt/muos/script/mount/union.sh start

	exit 1
}

DO_EJECT() {
	if ! MOUNTED; then
		SET_VAR "device" "storage/sdcard/active" "0"
		printf "Secondary storage already unmounted\n"

		exit 0
	fi

	/opt/muos/script/mount/union.sh stop

	if UNMOUNT_DEVICE; then
		/opt/muos/script/mount/bind.sh
		/opt/muos/script/mount/union.sh start

		printf "Secondary storage ejected: %s\n" "$SD_MOUNT"

		exit 0
	fi

	/opt/muos/script/mount/union.sh start

	printf "Secondary storage eject failed: %s\n" "$SD_MOUNT" >&2

	exit 1
}

DO_DOWN() {
	if ! MOUNTED; then
		SET_VAR "device" "storage/sdcard/active" "0"
		printf "Secondary storage already unmounted\n"

		exit 0
	fi

	if UNMOUNT_DEVICE; then
		printf "Secondary storage down: %s\n" "$SD_MOUNT"

		exit 0
	fi

	printf "Secondary storage down failed: %s\n" "$SD_MOUNT" >&2
	SET_VAR "device" "storage/sdcard/active" "0"

	exit 1
}

DO_STATUS() {
	if MOUNTED; then
		printf "Secondary storage mounted\n"

		exit 0
	fi

	printf "Secondary storage not mounted\n"

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
