#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/sync.sh

TYPE="${1:-}"
ACTION="${2:-}"
DURING_BOOT="${3:-0}" # 1 = do not trigger bind logic if we are booting

[ -z "$TYPE" ] && {
	printf "Missing storage type ( rom | sdcard | usb | ...? )\n" >&2
	exit 2
}

[ -z "$ACTION" ] && {
	printf "Missing action (mount | eject | down | status)\n" >&2
	exit 2
}

FIRST_INIT="$(GET_VAR "config" "boot/first_init")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"
CARD_MODE="$(GET_VAR "config" "danger/cardmode")"

DEV="$(GET_VAR "device" "storage/$TYPE/dev")"
SEP="$(GET_VAR "device" "storage/$TYPE/sep")"
NUM="$(GET_VAR "device" "storage/$TYPE/num")"

MOUNT_POINT="$(GET_VAR "device" "storage/$TYPE/mount")"

DEVICE="${DEV}${SEP}${NUM}"

# Fall back to whole-disk device if partition does not exist
if [ ! -b "/dev/$DEVICE" ] && [ -b "/dev/$DEV" ]; then
	DEVICE="$DEV"
fi

MOUNTED() {
	grep -qs " $MOUNT_POINT " /proc/mounts
}

MOUNT_DEVICE() {
	FS_INFO="$(blkid -o export "/dev/$DEVICE" 2>/dev/null)"
	FS_TYPE=
	FS_LABEL=
	while IFS='=' read -r FS_KEY FS_VAL; do
		case "$FS_KEY" in
			TYPE) FS_TYPE="$FS_VAL" ;;
			LABEL) FS_LABEL="$FS_VAL" ;;
		esac
	done <<EOF
$FS_INFO
EOF

	case "$FS_TYPE" in
		exfat) FS_OPTS="rw,noatime,nofail" ;;
		vfat) FS_OPTS="rw,utf8,noatime,nofail" ;;
		ext4) FS_OPTS="rw,noatime,nofail" ;;
		*) return 1 ;;
	esac

	[ -d "$MOUNT_POINT" ] || mkdir -p "$MOUNT_POINT"

	if mount -t "$FS_TYPE" -o "$FS_OPTS" "/dev/$DEVICE" "$MOUNT_POINT"; then
		SET_VAR "device" "storage/$TYPE/active" "1"
		SET_VAR "device" "storage/$TYPE/label" "${FS_LABEL:-}"

		# Apply scheduler tuning if supported
		if [ -e "/sys/block/$DEV/queue/scheduler" ]; then
			if [ "$CARD_MODE" = "noop" ]; then
				echo "noop" >"/sys/block/$DEV/queue/scheduler" 2>/dev/null
				echo "write back" >"/sys/block/$DEV/queue/write_cache" 2>/dev/null
			else
				echo "deadline" >"/sys/block/$DEV/queue/scheduler" 2>/dev/null
				echo "write through" >"/sys/block/$DEV/queue/write_cache" 2>/dev/null
			fi
		fi

		KERNEL_TUNING "$DEV"

		mkdir -p "$MOUNT_POINT/ROMS" "$MOUNT_POINT/BACKUP" "$MOUNT_POINT/ARCHIVE" "$MOUNT_POINT/ports"

		if [ -d "$MOUNT_POINT/MUOS/info/name" ]; then
			SYNC_FILE "$ROM_MOUNT" "$MOUNT_POINT" "MUOS/info/name/tag.txt" size "atomic,verify"
			SYNC_FILE "$ROM_MOUNT" "$MOUNT_POINT" "MUOS/info/name/folder.json" size "atomic,verify"
			SYNC_FILE "$ROM_MOUNT" "$MOUNT_POINT" "MUOS/info/name/global.json" size "atomic,verify"
		fi

		if [ "$FIRST_INIT" -eq 0 ]; then
			DELETE_CRUFT "$MOUNT_POINT"

			if [ "$TYPE" = "sdcard" ] && [ -d "$MOUNT_POINT/MUOS/theme/MustardOS" ]; then
				LOG_INFO "$0" 0 "STORAGE" "Refreshing default MustardOS theme on SD2"
				rm -rf "$MOUNT_POINT/MUOS/theme/MustardOS"
				mkdir -p "$MOUNT_POINT/MUOS/theme/MustardOS"
				cp -a "$MUOS_SHARE_DIR/theme/MustardOS/." "$MOUNT_POINT/MUOS/theme/MustardOS/"
			fi
		fi

		return 0
	fi

	return 1
}

UNMOUNT_DEVICE() {
	sync

	if umount "$MOUNT_POINT" 2>/dev/null || umount -l "$MOUNT_POINT" 2>/dev/null; then
		SET_VAR "device" "storage/$TYPE/active" "0"
		return 0
	fi

	return 1
}

DO_MOUNT() {
	if MOUNTED; then
		printf "%s already mounted\n" "$TYPE"
		exit 0
	fi

	if MOUNT_DEVICE; then
		[ "$DURING_BOOT" -eq 0 ] && /opt/muos/script/device/bind.sh
		printf "%s mounted: /dev/%s -> %s\n" "$TYPE" "$DEVICE" "$MOUNT_POINT"
		exit 0
	fi

	# At this point we don not know if it failed due to...
	# Missing device / Unsupported filesystem / General mount error
	if [ ! -b "/dev/$DEVICE" ]; then
		printf "%s device not present: /dev/%s\n" "$TYPE" "$DEVICE" >&2
	else
		printf "%s mount failed: /dev/%s\n" "$TYPE" "$DEVICE" >&2
	fi

	SET_VAR "device" "storage/$TYPE/active" "0"

	exit 1
}

DO_EJECT() {
	if ! MOUNTED; then
		SET_VAR "device" "storage/$TYPE/active" "0"
		printf "%s already unmounted\n" "$TYPE"
		exit 0
	fi

	if UNMOUNT_DEVICE; then
		[ "$DURING_BOOT" -eq 0 ] && /opt/muos/script/device/bind.sh
		printf "%s ejected: %s\n" "$TYPE" "$MOUNT_POINT"
		exit 0
	fi

	printf "%s eject failed: %s\n" "$TYPE" "$MOUNT_POINT" >&2
	exit 1
}

DO_DOWN() {
	if ! MOUNTED; then
		SET_VAR "device" "storage/$TYPE/active" "0"
		printf "%s already unmounted\n" "$TYPE"
		exit 0
	fi

	if UNMOUNT_DEVICE; then
		printf "%s down: %s\n" "$TYPE" "$MOUNT_POINT"
		exit 0
	fi

	printf "%s down failed: %s\n" "$TYPE" "$MOUNT_POINT" >&2
	SET_VAR "device" "storage/$TYPE/active" "0"

	exit 1
}

DO_STATUS() {
	if MOUNTED; then
		printf "%s mounted\n" "$TYPE"
		exit 0
	fi

	printf "%s not mounted\n" "$TYPE"
	exit 1
}

case "$ACTION" in
	mount) DO_MOUNT ;;
	eject) DO_EJECT ;;
	down) DO_DOWN ;;
	status) DO_STATUS ;;
	*)
		printf "Usage: %s <rom | sdcard | usb | ...?> <mount | eject | down | status>\n" "$0" >&2
		exit 2
		;;
esac
