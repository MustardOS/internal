#!/bin/sh

# Original backup script created for muOS 2405 Beans +
# Modified by Ali BEYAZ (aka symbuzzer) for backing up syncthing config

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

SD_DEVICE="${DC_STO_SDCARD_DEV}p${DC_STO_SDCARD_NUM}"
USB_DEVICE="${DC_STO_USB_DEV}p${DC_STO_USB_NUM}"

pkill -STOP muxtask

if grep -m 1 "$USB_DEVICE" /proc/partitions >/dev/null; then
	echo "USB mounted, archiving to USB"
	DEST_DIR="$DC_STO_USB_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
elif grep -m 1 "$SD_DEVICE" /proc/partitions >/dev/null; then
	echo "SD2 mounted, archiving to SD2"
	DEST_DIR="$DC_STO_SDCARD_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
else
	echo "Archiving to SD1"
	DEST_DIR="$DC_STO_ROM_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
fi

DEST_FILE="$DEST_DIR/muOS-Syncthing-$(date +"%Y-%m-%d_%H-%M").zip"

TO_BACKUP="
$DC_STO_ROM_MOUNT/MUOS/syncthing
$DC_STO_SDCARD_MOUNT/MUOS/syncthing
"
VALID_BACKUP=$(mktemp)

for BACKUP in $TO_BACKUP; do
	if [ -e "$BACKUP" ]; then
		echo "$BACKUP" >>"$VALID_BACKUP"
		echo "Found: $BACKUP"
	fi
done

if [ ! -s "$VALID_BACKUP" ]; then
	echo "No valid files found to backup!"
	sleep 1
	rm "$VALID_BACKUP"
else
	cd /
	echo "Archiving Syncthing Config"

	BACKUP_FILES=""
	while IFS= read -r FILE; do
		BACKUP_FILES="$BACKUP_FILES \"$FILE\""
	done <"$VALID_BACKUP"
	eval "zip -ru9 $DEST_FILE $BACKUP_FILES"

	rm "$VALID_BACKUP"
fi

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
