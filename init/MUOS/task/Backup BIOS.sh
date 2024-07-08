#!/bin/sh

# Backup script created for muOS 2405 Beans +
# This should backup the BIOS folder.

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

SD_DEVICE="${DC_STO_SDCARD_DEV}p${DC_STO_SDCARD_NUM}"
USB_DEVICE="${DC_STO_USB_DEV}p${DC_STO_USB_NUM}"

pkill -STOP muxtask
/opt/muos/extra/muxlog &
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

if grep -m 1 "$USB_DEVICE" /proc/partitions >/dev/null; then
	echo "USB mounted, archiving to USB" >/tmp/muxlog_info
	DEST_DIR="$DC_STO_USB_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
elif grep -m 1 "$SD_DEVICE" /proc/partitions >/dev/null; then
	echo "SD2 mounted, archiving to SD2" >/tmp/muxlog_info
	DEST_DIR="$DC_STO_SDCARD_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
else
	echo "Archiving to SD1" >/tmp/muxlog_info
	DEST_DIR="$DC_STO_ROM_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
fi

DEST_FILE="$DEST_DIR/muOS-BIOS-$(date +"%Y-%m-%d_%H-%M").zip"

# Capture PICO-8 files and backup
PICO8_FILES="
$DC_STO_ROM_MOUNT/MUOS/emulator/pico8/pico8_64
$DC_STO_ROM_MOUNT/MUOS/emulator/pico8/pico8_dyn
$DC_STO_ROM_MOUNT/MUOS/emulator/pico8/pico8.dat
"

TO_BACKUP="
$DC_STO_ROM_MOUNT/MUOS/bios
$DC_STO_SDCARD_MOUNT/MUOS/bios
$PICO8_FILES
"
VALID_BACKUP=$(mktemp)

for BACKUP in $TO_BACKUP; do
	if [ -e "$BACKUP" ]; then
		echo "$BACKUP" >>"$VALID_BACKUP"
		echo "Found: $BACKUP" >/tmp/muxlog_info
	fi
done

if [ ! -s "$VALID_BACKUP" ]; then
	echo "No valid files found to backup!" >/tmp/muxlog_info
	sleep 1
	rm "$VALID_BACKUP"
else
	cd /
	echo "Archiving BIOS" >/tmp/muxlog_info

	BACKUP_FILES=""
	while IFS= read -r FILE; do
		BACKUP_FILES="$BACKUP_FILES \"$FILE\""
	done <"$VALID_BACKUP"
	eval "zip -ru9 $DEST_FILE $BACKUP_FILES" >"$TMP_FILE" 2>&1 &

	C_LINE=""
	while true; do
		IS_WORKING=$(pgrep -f "zip")

		if [ -s "$TMP_FILE" ]; then
			N_LINE=$(tail -n 1 "$TMP_FILE" | sed 's/^[[:space:]]*//')
			if [ "$N_LINE" != "$C_LINE" ]; then
				# Don't want to scare people unnecessarily!
				if ! echo "$N_LINE" | grep -q "^zip warning:"; then
					echo "$N_LINE"
					echo "$N_LINE" >/tmp/muxlog_info
				fi
				C_LINE="$N_LINE"
			fi
		fi

		if [ -z "$IS_WORKING" ]; then
			break
		fi
	done

	rm "$VALID_BACKUP"

	echo "Sync Filesystem" >/tmp/muxlog_info
	sync

	echo "All Done!" >/tmp/muxlog_info
	sleep 1
fi

pkill -CONT muxtask

while true; do
	if ! toybox ps -Al | grep '[m]uxtask' | grep 'T' >/dev/null; then
		echo "Waiting to quit..." >/tmp/muxlog_info
		break
	fi
	sleep 0.1
	pkill -CONT muxtask
done

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

killall -q "$(basename "$0")"
