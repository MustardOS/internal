#!/bin/sh

# Backup script created for muOS 2405 Beans +
# This grabs all save files and save states and adds them to a .zip archive for easy restoration later using the muOS Backup Manager.

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

# Define Drastic source directories
if [ -d "/mnt/mmc/MUOS/emulator/" ]; then
    Drastic_SAVE_DIR="/mnt/mmc/MUOS/emulator/drastic/backup"
    Drastic_SAVESTATE_DIR="/mnt/mmc/MUOS/emulator/drastic/savestates"
else
    Drastic_SAVE_DIR=""
    Drastic_SAVESTATE_DIR""
fi

# Define additional source directories
if [ -d "/mnt/mmc/MUOS/save/" ]; then
    Drastic_Steward_SAVE_DIR="/mnt/mmc/MUOS/save/drastic/backup"
    Drastic_Steward_SAVESTATE_DIR="/mnt/mmc/MUOS/save/drastic/savestates"
else
    Drastic_Steward_SAVE_DIR=""
    Drastic_Steward_SAVESTATE_DIR=""
fi

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

DEST_FILE="$DEST_DIR/Drastic-Save-$DATE.zip"

# Change to root so we capture full path in .zip
cd /

## Create the backup
echo "Archiving Saves" > /tmp/muxlog_info
zip -ru9 "$DEST_FILE" "$Drastic_SAVE_DIR" "$Drastic_SAVESTATE_DIR" "$Drastic_Steward_SAVE_DIR" "$Drastic_Steward_SAVESTATE_DIR" > "$TMP_FILE" 2>&1 &

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
killall -q "Backup Drastic Saves.sh"

