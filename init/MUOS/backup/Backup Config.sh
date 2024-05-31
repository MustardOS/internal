#!/bin/sh

# Backup script created for muOS 2405 Beans +
# This should backup all core overrides, core assignments, favourites, and RA global config

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

# Core Overrides
RA_OVERRIDES="/mnt/mmc/MUOS/info/config"

# Global Configs
RA64_CONFIG="/mnt/mmc/MUOS/retroarch/retroarch.cfg"
RA32_CONFIG="/mnt/mmc/MUOS/retroarch/retroarch32.cfg"

# Core Assignments
MU_ASSIGN="/mnt/mmc/MUOS/info/core"

# Favourites
MU_FAVES="/mnt/mmc/MUOS/info/favourite"

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
DEST_FILE="$DEST_DIR/Config-$DATE.zip"

# Change to root so we capture full path in .zip
cd /

# Create the backup
echo "Archiving Config" > /tmp/muxlog_info
zip -ru9 "$DEST_FILE" "$RA_OVERRIDES" "$RA64_CONFIG" "$RA32_CONFIG" "$MU_ASSIGN" "$MU_FAVES" > "$TMP_FILE" 2>&1 &

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
killall -q "Backup Config.sh"