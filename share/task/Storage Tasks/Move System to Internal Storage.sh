#!/bin/sh
# HELP: TrimUI only. Copies MustardOS from the SD card to the internal storage so the device starts without the card. A first install erases the internal storage, including the original TrimUI system. Running it from a newer SD card replaces the internal system and keeps your internal content.
# ICON: storage
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/config.sh
. /opt/muos/script/var/storage.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "move_system_internal" "Move System to Internal Storage"

SCRIPT_PATH=$(readlink -f "$0")
EMMC_MODULE=/opt/muos/device/module/tui_emmc.ko

SD=mmcblk0
LOGICAL_OFFSET=40960
BOOT_START=73728
BOOT_END=239616
ROOT_START=319488
ROMS_MIN_MIB=512

WORK=/run/muos/emmc-install
OVERLAY=$WORK/overlay
SRC_ROOT=$WORK/source
DST_ROOT=$WORK/target

FAIL_NOTE="Nothing was changed"

IS_MOUNTED() {
	findmnt -rn -M "$1" >/dev/null 2>&1
}

CLEAN_UP() {
	for CLEAN_MOUNT in "$DST_ROOT" "$SRC_ROOT"; do
		IS_MOUNTED "$CLEAN_MOUNT" && umount "$CLEAN_MOUNT"
	done

	IS_MOUNTED "$DST_ROOT" || IS_MOUNTED "$SRC_ROOT" || {
		rm -f "$OVERLAY/init" "$OVERLAY/tui_emmc.ko" "$WORK"/*.gz "$WORK"/*.bin "$WORK"/*.img
		rmdir "$OVERLAY" "$SRC_ROOT" "$DST_ROOT" "$WORK" 2>/dev/null
	}
}

trap CLEAN_UP EXIT HUP INT TERM

FAIL() {
	TASK_ERROR "$1" "$2"
	TASK_COMPLETE "$FAIL_NOTE"
	exit 1
}

CANCEL() {
	TASK_COMPLETE "Nothing was changed"
	exit 0
}

SIZE_TEXT() {
	printf '%d.%d GB' $(($1 / 1024)) $(($1 % 1024 * 10 / 1024))
}

U32() {
	od -An -tu4 -j "$2" -N4 "$1" | tr -d ' \n'
}

HEX_AT() {
	od -An -tx1 -j "$2" -N "$3" "$1" | tr -d ' \n'
}

LE32() {
	printf "$(printf '\\%03o\\%03o\\%03o\\%03o' $(($1 & 255)) $(($1 >> 8 & 255)) $(($1 >> 16 & 255)) $(($1 >> 24 & 255)))"
}

HEX_BYTES() {
	HEX_REST=$1
	while [ -n "$HEX_REST" ]; do
		HEX_PAIR=${HEX_REST%"${HEX_REST#??}"}
		HEX_REST=${HEX_REST#??}
		printf "\\$(printf '%03o' $((0x$HEX_PAIR)))"
	done
}

REGION_SUM() {
	dd if="$1" bs=512 skip="$2" count="$3" 2>/dev/null | sha256sum | cut -d ' ' -f 1
}

TREE_SUM() {
	(cd "$1" && find . -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum | cut -d ' ' -f 1)
}

USED_KIB() {
	df -Pk "$1" | awk 'NR == 2 { print $3 }'
}

PART_VALUE() {
	cat "/sys/block/$1/$1p$2/$3" 2>/dev/null
}

FIND_EMMC() {
	for EMMC_BLOCK in /sys/block/mmcblk*; do
		[ "$(cat "$EMMC_BLOCK/device/type" 2>/dev/null)" = MMC ] || continue
		printf '%s' "${EMMC_BLOCK##*/}"
		return 0
	done
	return 1
}

WAIT_FOR() {
	WAIT_COUNT=0
	until [ -b "$1" ]; do
		[ "$WAIT_COUNT" -ge 100 ] && return 1
		sleep 0.1
		WAIT_COUNT=$((WAIT_COUNT + 1))
	done
}

BOOT_IMAGE_ID() {
	{
		dd if="$1" bs="$2" skip=1 2>/dev/null | head -c "$3"
		LE32 "$3"
		dd if="$1" bs="$2" skip="$4" 2>/dev/null | head -c "$5"
		LE32 "$5"
		LE32 0
	} | sha1sum | cut -d ' ' -f 1
}

WRITE_INIT() {
	cat >"$1" <<'EOF'
#!/bin/sh

EMMC_FIND() {
	for EMMC_BLOCK in /sys/block/mmcblk*; do
		[ "$(cat "$EMMC_BLOCK/device/type" 2>/dev/null)" = MMC ] || continue
		[ -b "/dev/${EMMC_BLOCK##*/}p5" ] || continue
		EMMC_DEV=${EMMC_BLOCK##*/}
		return 0
	done
	return 1
}

SET_VALUE() {
	VALUE_FILE="/root/opt/muos/$1"
	[ -f "$VALUE_FILE" ] || return 0
	[ "$(cat "$VALUE_FILE")" = "$2" ] || printf '%s' "$2" >"$VALUE_FILE"
}

do_root() {
	mount -t devtmpfs none /dev
	mkdir /dev/pts
	mount -t devpts none /dev/pts
	mount -t sysfs sysfs /sys
	exec </dev/console >/dev/console 2>&1

	echo "[$0]: Starting Watchdog"
	watchdog -t 5 /dev/watchdog0

	mkdir -p /root /sys /proc
	mount -t proc -o nodev,noexec,nosuid proc /proc

	echo "[$0]: Waiting for internal storage..."
	EMMC_DEV=
	WAIT=0
	until EMMC_FIND || [ "$WAIT" -ge 15 ]; do
		[ "$WAIT" -eq 3 ] && insmod /tui_emmc.ko
		sleep 1
		WAIT=$((WAIT + 1))
	done

	ROOT_DEV=${EMMC_DEV:-mmcblk0}
	if [ -z "$EMMC_DEV" ]; then
		echo "[$0]: Internal storage not found, waiting for SD card..."
		while [ ! -b /dev/mmcblk0p5 ]; do
			sleep 1
		done
	fi

	echo "[$0]: Mounting rootfs"
	mount "/dev/${ROOT_DEV}p5" /root || return 1

	if [ -n "$EMMC_DEV" ]; then
		SET_VALUE device/config/storage/boot/dev "$EMMC_DEV"
		SET_VALUE device/config/storage/root/dev "$EMMC_DEV"
		SET_VALUE device/config/storage/rom/dev "$EMMC_DEV"
		SET_VALUE device/config/storage/sdcard/dev mmcblk0
		SET_VALUE config/danger/emmc 0
	fi

	mount --move /proc /root/proc
	mount --move /sys /root/sys
	mount --move /dev /root/dev

	echo "[$0]: Switching to rootfs"
	exec switch_root /root /sbin/init || return 1
}

if ! do_root; then
	echo "Boot failed!"
	/bin/ash
fi
EOF
	chmod 755 "$1"
}

TASK_STATUS "Checking Device"

case "$(GET_VAR "device" "board/name")" in
	tui-*) ;;
	*) FAIL "unsupported" "This task is only for TrimUI devices" ;;
esac

[ "$(findmnt -n -o SOURCE /)" = "/dev/${SD}p5" ] ||
	FAIL "not_sd" "Start MustardOS from the SD card to move it to internal storage"

[ "$(PART_VALUE "$SD" 1 start)" = "$BOOT_START" ] && [ "$(PART_VALUE "$SD" 5 start)" = "$ROOT_START" ] ||
	FAIL "layout" "The SD card does not use the expected MustardOS partition layout"

[ -x "$MUOS_MKE2FS" ] && [ -f "$MUOS_MKE2FS_CONF" ] && [ -f "$EMMC_MODULE" ] ||
	FAIL "tooling" "Required MustardOS system files are missing"

TASK_STATUS "Finding Internal Storage"

if ! EMMC=$(FIND_EMMC); then
	grep -q '^tui_emmc ' /proc/modules || insmod "$EMMC_MODULE" ||
		FAIL "no_emmc" "Internal storage could not be enabled"

	WAIT_COUNT=0
	until EMMC=$(FIND_EMMC); do
		[ "$WAIT_COUNT" -ge 50 ] && FAIL "no_emmc" "Internal storage was not found"
		sleep 0.1
		WAIT_COUNT=$((WAIT_COUNT + 1))
	done
fi

if grep -q "^/dev/$EMMC" /proc/mounts; then
	TASK_STATUS "Ejecting Internal Storage"
	/opt/muos/script/device/storage.sh "sdcard" "eject" >/dev/null 2>&1
	grep -q "^/dev/$EMMC" /proc/mounts &&
		FAIL "emmc_busy" "Internal storage is in use and could not be ejected"
fi

EMMC_SECTORS=$(cat "/sys/block/$EMMC/size")
SPACE_MIB=$(((EMMC_SECTORS - ROOT_START - 34) / 2048))
ROOT_USED_KIB=$(USED_KIB /)
ROOT_MIN_MIB=$(((ROOT_USED_KIB * 115 / 100 / 1024 + 512 + 511) / 512 * 512))

[ $((ROOT_MIN_MIB + ROMS_MIN_MIB)) -le "$SPACE_MIB" ] ||
	FAIL "too_small" "$(printf "Internal storage is too small. The system needs %s and there is %s available" \
		"$(SIZE_TEXT "$ROOT_MIN_MIB")" "$(SIZE_TEXT "$SPACE_MIB")")"

MODE=erase
if [ "$(blkid -o value -s LABEL "/dev/${EMMC}p5" 2>/dev/null)" = ROOTFS ] &&
	[ "$(PART_VALUE "$EMMC" 5 start)" = "$ROOT_START" ] && [ -b "/dev/${EMMC}p6" ] &&
	[ $(($(PART_VALUE "$EMMC" 5 size) / 2048)) -ge "$ROOT_MIN_MIB" ]; then
	MODE=$(TASK_PROMPT "emmc_mode" "choice" "Internal Storage" \
		"MustardOS is already installed on the internal storage. Replace the system and keep your internal content, or erase everything and choose a new layout." \
		"Replace System|Erase and Reinstall" "Replace System") || CANCEL
	[ "$MODE" = "Replace System" ] && MODE=update || MODE=erase
fi

if [ "$MODE" = erase ]; then
	SIZE_OPTIONS=
	SIZE_DEFAULT=
	SIZE_MIB=$ROOT_MIN_MIB
	while [ $((SIZE_MIB + ROMS_MIN_MIB)) -le "$SPACE_MIB" ] && [ "$SIZE_MIB" -lt $((ROOT_MIN_MIB + 2048)) ]; do
		SIZE_LABEL="$(SIZE_TEXT "$SIZE_MIB") System, $(SIZE_TEXT $((SPACE_MIB - SIZE_MIB))) Content"
		[ -n "$SIZE_DEFAULT" ] || {
			SIZE_LABEL="$SIZE_LABEL (Suggested)"
			SIZE_DEFAULT=$SIZE_LABEL
		}
		SIZE_OPTIONS="${SIZE_OPTIONS:+$SIZE_OPTIONS|}$SIZE_LABEL"
		SIZE_MIB=$((SIZE_MIB + 512))
	done

	SIZE_CHOICE=$(TASK_PROMPT "emmc_size" "choice" "Internal Storage Layout" \
		"$(printf "The system uses %s of the %s available. Choose how much to keep for the system, and the rest holds your content." \
			"$(SIZE_TEXT $((ROOT_USED_KIB / 1024)))" "$(SIZE_TEXT "$SPACE_MIB")")" \
		"$SIZE_OPTIONS" "$SIZE_DEFAULT") || CANCEL

	ROOT_MIB=$ROOT_MIN_MIB
	while [ "$ROOT_MIB" -lt "$SIZE_MIB" ]; do
		case "$SIZE_CHOICE" in
			"$(SIZE_TEXT "$ROOT_MIB") System,"*) break ;;
		esac
		ROOT_MIB=$((ROOT_MIB + 512))
	done
	[ "$ROOT_MIB" -lt "$SIZE_MIB" ] || FAIL "layout" "The chosen layout was not recognised"

	CONFIRM=$(TASK_PROMPT "emmc_confirm" "confirm" "Move System to Internal Storage" \
		"Everything on the internal storage, including the original TrimUI system, will be erased. The SD card is not changed." \
		"Erase and Install|Cancel" "Cancel") || CANCEL
	[ "$CONFIRM" = "Erase and Install" ] || CANCEL
else
	CONFIRM=$(TASK_PROMPT "emmc_confirm" "confirm" "Replace Internal System" \
		"The system on the internal storage will be replaced with the one on this SD card. Your internal content is kept. The SD card is not changed." \
		"Replace System|Cancel" "Cancel") || CANCEL
	[ "$CONFIRM" = "Replace System" ] || CANCEL
fi

TASK_STATUS "Preparing Boot Image"

mkdir -p "$OVERLAY" "$SRC_ROOT" "$DST_ROOT" || FAIL "workspace" "Could not prepare the workspace"

SD_BOOT=/dev/${SD}p1
EMMC_BOOT=/dev/${EMMC}p1

[ "$(head -c 8 "$SD_BOOT")" = "ANDROID!" ] || FAIL "boot_image" "The SD card boot image was not recognised"

KERNEL_SIZE=$(U32 "$SD_BOOT" 8)
RAMDISK_SIZE=$(U32 "$SD_BOOT" 16)
SECOND_SIZE=$(U32 "$SD_BOOT" 24)
PAGE_SIZE=$(U32 "$SD_BOOT" 36)
RAMDISK_PAGE=$((1 + (KERNEL_SIZE + PAGE_SIZE - 1) / PAGE_SIZE))

[ "$SECOND_SIZE" -eq 0 ] && [ "$PAGE_SIZE" -ge 2048 ] ||
	FAIL "boot_image" "The SD card boot image layout is not supported"

[ "$(BOOT_IMAGE_ID "$SD_BOOT" "$PAGE_SIZE" "$KERNEL_SIZE" "$RAMDISK_PAGE" "$RAMDISK_SIZE")" = "$(HEX_AT "$SD_BOOT" 576 20)" ] ||
	FAIL "boot_image" "The SD card boot image failed its checksum"

WRITE_INIT "$OVERLAY/init"
cp "$EMMC_MODULE" "$OVERLAY/tui_emmc.ko" || FAIL "workspace" "Could not stage the internal storage module"

(cd "$OVERLAY" && printf 'init\ntui_emmc.ko\n' | cpio -o -H newc 2>/dev/null) | gzip -9 >"$WORK/overlay.gz" &&
	dd if="$SD_BOOT" bs="$PAGE_SIZE" skip="$RAMDISK_PAGE" 2>/dev/null | head -c "$RAMDISK_SIZE" >"$WORK/ramdisk.gz" &&
	cat "$WORK/ramdisk.gz" "$WORK/overlay.gz" >"$WORK/ramdisk.new.gz" ||
	FAIL "boot_image" "Could not build the internal storage ramdisk"

zcat "$WORK/overlay.gz" | cpio -t 2>/dev/null | grep -qx tui_emmc.ko && gzip -t "$WORK/ramdisk.new.gz" ||
	FAIL "boot_image" "The internal storage ramdisk could not be read back"

NEW_RAMDISK_SIZE=$(wc -c <"$WORK/ramdisk.new.gz")
NEW_RAMDISK_PAGES=$(((NEW_RAMDISK_SIZE + PAGE_SIZE - 1) / PAGE_SIZE))

[ $(((RAMDISK_PAGE + NEW_RAMDISK_PAGES) * PAGE_SIZE)) -le $(($(PART_VALUE "$SD" 1 size) * 512)) ] ||
	FAIL "boot_image" "The internal storage ramdisk does not fit the boot partition"

FAIL_NOTE="The SD card was not changed. The internal storage is incomplete, so run this task again before starting without the SD card."

if [ "$MODE" = erase ]; then
	TASK_STATUS "Partitioning Internal Storage"

	sfdisk -d "/dev/$SD" | awk -v sd="/dev/${SD}p" -v rs=$((ROOT_MIB * 2048)) -v rstart="$ROOT_START" '
		/^device:/ || /^last-lba:/ { next }
		index($0, sd "5 :") == 1 { sub(/size= *[0-9]+/, "size=" rs) }
		index($0, sd "6 :") == 1 { sub(/start= *[0-9]+/, "start=" (rstart + rs)); sub(/size= *[0-9]+, */, "") }
		/start=/ { sub(/^[^:]*: */, "") }
		{ print }
	' | sfdisk -q --no-reread --no-tell-kernel "/dev/$EMMC" >/dev/null 2>&1 ||
		FAIL "partition" "The internal storage could not be partitioned"

	blockdev --rereadpt "/dev/$EMMC" ||
		FAIL "partition" "The new internal storage partitions could not be loaded"
fi

WAIT_FOR "/dev/${EMMC}p5" && WAIT_FOR "/dev/${EMMC}p6" &&
	[ "$(PART_VALUE "$EMMC" 1 start)" = "$BOOT_START" ] && [ "$(PART_VALUE "$EMMC" 5 start)" = "$ROOT_START" ] ||
	FAIL "partition" "The internal storage partitions are not in the expected place"

TASK_STATUS "Copying Boot Chain"

dd if="/dev/$SD" of="/dev/$EMMC" bs=512 skip=34 seek=34 count=2014 conv=notrunc,fsync 2>/dev/null &&
	dd if="/dev/$SD" of="/dev/$EMMC" bs=1M skip=1 seek=1 count=$((BOOT_END / 2048 - 1)) conv=notrunc,fsync 2>/dev/null ||
	FAIL "boot_chain" "The boot chain could not be written to internal storage"

[ "$(REGION_SUM "/dev/$SD" 34 $((BOOT_END - 34)))" = "$(REGION_SUM "/dev/$EMMC" 34 $((BOOT_END - 34)))" ] ||
	FAIL "boot_chain" "The boot chain on internal storage did not verify"

TASK_STATUS "Writing Boot Image"

dd if="$WORK/ramdisk.new.gz" of="$EMMC_BOOT" bs="$PAGE_SIZE" seek="$RAMDISK_PAGE" conv=sync,notrunc,fsync 2>/dev/null &&
	LE32 "$NEW_RAMDISK_SIZE" | dd of="$EMMC_BOOT" bs=1 seek=16 conv=notrunc,fsync 2>/dev/null ||
	FAIL "boot_image" "The boot image could not be written to internal storage"

NEW_ID=$(BOOT_IMAGE_ID "$EMMC_BOOT" "$PAGE_SIZE" "$KERNEL_SIZE" "$RAMDISK_PAGE" "$NEW_RAMDISK_SIZE")
{
	HEX_BYTES "$NEW_ID"
	dd if=/dev/zero bs=12 count=1 2>/dev/null
} | dd of="$EMMC_BOOT" bs=1 seek=576 conv=notrunc,fsync 2>/dev/null ||
	FAIL "boot_image" "The boot image checksum could not be written"

[ "$(U32 "$EMMC_BOOT" 16)" = "$NEW_RAMDISK_SIZE" ] && [ "$(HEX_AT "$EMMC_BOOT" 576 20)" = "$NEW_ID" ] &&
	dd if="$EMMC_BOOT" bs="$PAGE_SIZE" skip="$RAMDISK_PAGE" 2>/dev/null | head -c "$NEW_RAMDISK_SIZE" | cmp -s - "$WORK/ramdisk.new.gz" ||
	FAIL "boot_image" "The boot image on internal storage did not verify"

TASK_STATUS "Writing Bootloader Partition Table"

dd if=/dev/zero of="$WORK/logical.img" bs=512 count=0 seek=$((EMMC_SECTORS - LOGICAL_OFFSET)) 2>/dev/null &&
	sfdisk -d "/dev/$EMMC" | awk -v off="$LOGICAL_OFFSET" '
		/^device:/ || /^last-lba:/ { next }
		/^first-lba:/ { print "first-lba: " ($2 - off); next }
		match($0, /start= *[0-9]+/) {
			value = substr($0, RSTART + 6, RLENGTH - 6) + 0
			$0 = substr($0, 1, RSTART - 1) "start=" (value - off) substr($0, RSTART + RLENGTH)
			sub(/^[^:]*: */, "")
		}
		{ print }
	' | sfdisk -q --no-reread "$WORK/logical.img" >/dev/null 2>&1 &&
	dd if="$WORK/logical.img" of="/dev/$EMMC" bs=512 count=34 seek="$LOGICAL_OFFSET" conv=notrunc,fsync 2>/dev/null ||
	FAIL "partition" "The bootloader partition table could not be written"

[ "$(REGION_SUM "$WORK/logical.img" 0 34)" = "$(REGION_SUM "/dev/$EMMC" "$LOGICAL_OFFSET" 34)" ] ||
	FAIL "partition" "The bootloader partition table did not verify"
rm -f "$WORK/logical.img"

TASK_STATUS "Formatting System Partition"

MKE2FS_CONFIG="$MUOS_MKE2FS_CONF" "$MUOS_MKE2FS" -q -F -t ext4 -L ROOTFS "/dev/${EMMC}p5" >/dev/null 2>&1 ||
	FAIL "format" "The internal system partition could not be formatted"

mount --bind / "$SRC_ROOT" && mount -t ext4 "/dev/${EMMC}p5" "$DST_ROOT" ||
	FAIL "mount" "The system partitions could not be mounted"

TASK_STATUS "Copying System"
TASK_DETAIL "This takes several minutes"

rsync -aH --numeric-ids "$SRC_ROOT/" "$DST_ROOT/" >/dev/null 2>&1 &
COPY_PID=$!
while kill -0 "$COPY_PID" 2>/dev/null; do
	TASK_PROGRESS "$(USED_KIB "$DST_ROOT")" "$ROOT_USED_KIB"
	sleep 2
done
wait "$COPY_PID"
COPY_STATUS=$?
[ "$COPY_STATUS" -eq 0 ] || [ "$COPY_STATUS" -eq 24 ] ||
	FAIL "copy" "$(printf "The system could not be copied to internal storage (rsync %s)" "$COPY_STATUS")"

TASK_STATUS "Verifying System"
TASK_PROGRESS 0 0

for TREE in opt/muos/script opt/muos/frontend lib/modules; do
	[ "$(TREE_SUM "$SRC_ROOT/$TREE")" = "$(TREE_SUM "$DST_ROOT/$TREE")" ] ||
		FAIL "verify" "$(printf "The copied system did not verify: /%s" "$TREE")"
done

TASK_STATUS "Configuring Internal System"

[ "$MODE" = erase ] && FACTORY_RESET=1 || FACTORY_RESET=0
printf '%s' "$FACTORY_RESET" >"$DST_ROOT/opt/muos/config/boot/factory_reset" &&
	printf '0' >"$DST_ROOT/opt/muos/config/danger/emmc" &&
	rm -f "$DST_ROOT$SCRIPT_PATH" ||
	FAIL "configure" "The internal system could not be configured"

sync
umount "$DST_ROOT" && umount "$SRC_ROOT" ||
	FAIL "unmount" "The system partitions could not be unmounted"

rm -f "$SCRIPT_PATH"
sync

if [ "$MODE" = erase ]; then
	TASK_DETAIL "The first start from internal storage sets up the content partition"
else
	TASK_DETAIL "Your internal content was kept"
fi

TASK_COMPLETE "MustardOS is installed on internal storage. Power off, remove the SD card, then power on."
exit 0
