#!/bin/sh
# HELP: Storage Report - Checks SD cards and USB storage, free space, file system errors and read speed, then saves a report to SD1
# ICON: storage
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

DIAG_BEGIN "storage_report" "Storage Report"

DIAG_SECTION "muOS storage configuration"
DIAG_CONFIG "$MUOS_CONF_DEVICE/storage"

DIAG_SECTION "Mounts and free space"
DIAG_CMD "Free space" df -h
grep -E "^/dev/(mmcblk|sd)" /proc/mounts | while read -r DEV MOUNT TYPE OPTIONS _; do
	DIAG_KV "$MOUNT" "$DEV $TYPE $OPTIONS"
done
for MOUNT in $(awk '$1 ~ /^\/dev\/(mmcblk|sd)/ { print $2 }' /proc/mounts); do
	case "$(awk -v m="$MOUNT" '$2 == m { print $4 }' /proc/mounts)" in
		ro | ro,*) DIAG_FINDING "STORAGE" "$MOUNT is mounted read only. The card may have errors or be failing." ;;
	esac
	USED=$(df "$MOUNT" 2>/dev/null | awk 'NR == 2 { gsub("%", "", $5); print $5 }')
	DIAG_IS_NUM "$USED" && [ "$USED" -ge 95 ] && DIAG_FINDING "STORAGE" "$MOUNT is ${USED}% full. Saves and settings can fail to write."
done
for ROLE in rom sdcard usb; do
	DEV=$(GET_VAR "device" "storage/$ROLE/dev" 2>/dev/null)
	MOUNT=$(GET_VAR "device" "storage/$ROLE/mount" 2>/dev/null)
	[ -n "$DEV" ] && [ -n "$MOUNT" ] || continue
	if [ -b "/dev/$DEV" ] && ! grep -q " $MOUNT " /proc/mounts; then
		DIAG_FINDING "STORAGE" "The $ROLE storage device /dev/$DEV is present but not mounted at $MOUNT."
	fi
done

DIAG_SECTION "Devices"
DIAG_CMD "lsblk" lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
DIAG_CMD "blkid" blkid
for CARD in /sys/block/mmcblk*/device; do
	[ -d "$CARD" ] || continue
	DIAG_OUT "-- $(basename "$(dirname "$CARD")")"
	for ATTR in type name manfid oemid date hwrev fwrev csd; do
		[ -r "$CARD/$ATTR" ] && DIAG_KV "   $ATTR" "$(DIAG_READ "$CARD/$ATTR")"
	done
done

DIAG_SECTION "Read speed"
sync
echo 3 >/proc/sys/vm/drop_caches 2>/dev/null
for BLOCK in /sys/block/mmcblk[0-9] /sys/block/sd[a-z]; do
	[ -d "$BLOCK" ] || continue
	NAME=$(basename "$BLOCK")
	START=$(tr -d . </proc/uptime | cut -d' ' -f1)
	dd if="/dev/$NAME" of=/dev/null bs=1M count=64 2>/dev/null || continue
	END=$(tr -d . </proc/uptime | cut -d' ' -f1)
	ELAPSED=$((END - START))
	[ "$ELAPSED" -le 0 ] && ELAPSED=1
	SPEED=$((64 * 100 / ELAPSED))
	DIAG_KV "$NAME" "64 MB in $((ELAPSED * 10)) ms (about $SPEED MB/s)"
	[ "$SPEED" -lt 8 ] && DIAG_FINDING "STORAGE" "$NAME reads at only about $SPEED MB/s. Expect slow loading. The card may be counterfeit or worn."
done

DIAG_SECTION "Kernel messages"
DIAG_DMESG "mmc|sdhci|I/O error|EXT4-fs|FAT-fs|exfat|vfat|buffer_io|blk_update|usb-storage|scsi" 80
ERRORS=$(dmesg 2>/dev/null | grep -ciE "I/O error|blk_update_request|EXT4-fs error|FAT-fs \(.*\): error|exfat.*error|mmc[0-9]: (error|timeout)")
[ "${ERRORS:-0}" -gt 0 ] && DIAG_FINDING "STORAGE" "The kernel logged $ERRORS storage errors since boot. Back up the card and check it on a computer."

DIAG_FINISH "Storage report saved"
exit 0
