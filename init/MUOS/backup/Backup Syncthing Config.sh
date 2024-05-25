#!/bin/sh

# Original backup script created for muOS 2405 Beans +
# Modified by Ali BEYAZ (aka symbuzzer) for backing up synching config
# This should backup syncthing config

# Suspend the muxbackup program
pkill -STOP muxbackup

# Fire up the logger!
/opt/muos/extra/muxlog &
sleep 1

echo "Waiting..." > /tmp/muxlog_info
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

# Grab current date
DATE=$(date +%Y-%m-%d)

# Syncthing config
MU_SYNCTHING="/mnt/mmc/MUOS/syncthing"

# Set destination file based on priority
# USB -> SD2 -> SD1
if grep -m 1 "sda1" /proc/partitions > /dev/null; then
    echo "USB mounted, archiving to USB" > /tmp/muxlog_info
    mkdir -p "/mnt/usb/BACKUP/"
    DEST_DIR="/mnt/usb/BACKUP"
elif grep -m 1 "mmcblk1p1" /proc/partitions > /dev/null; then
    echo "SD2 mounted, archiving to SD2" > /tmp/muxlog_info
    mkdir -p "/mnt/sdcard/BACKUP/"
    DEST_DIR="/mnt/sdcard/BACKUP"
else
    echo "Archiving to SD1" > /tmp/muxlog_info
    DEST_DIR="/mnt/mmc/BACKUP"
fi

# Set Destination File
DEST_FILE="$DEST_DIR/SyncthingConfig-$DATE.zip"

# Change to root so we capture full path in .zip
cd /

# Create the backup
echo "Archiving Syncthing Config" > /tmp/muxlog_info
zip -ru9 "$DEST_FILE" "$MU_SYNCTHING" > "$TMP_FILE" 2>&1 &

# Tail zip process and push to muxlog
C_LINE=""
while true; do
	IS_WORKING=$(ps aux | grep '[z]ip' | awk '{print $1}')

	if [ -s "$TMP_FILE" ]; then
		N_LINE=$(tail -n 1 "$TMP_FILE" | sed 's/^[[:space:]]*//')
		if [ "$N_LINE" != "$C_LINE" ]; then
			echo "$N_LINE"
			echo "$N_LINE" > /tmp/muxlog_info
			C_LINE="$N_LINE"
		fi
	fi

	if [ -z "$IS_WORKING" ]; then
		break
	fi
	
	sleep 0.25
done

# Sync filesystem just-in-case :)
echo "Sync Filesystem" > /tmp/muxlog_info
sync

echo "All Done!" > /tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

# Resume the muxbackup program
pkill -CONT muxbackup
killall -q "Backup Syncthing Config.sh"