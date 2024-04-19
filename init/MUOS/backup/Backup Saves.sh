#!/bin/sh

# Backup script designed to grab all save files and save states and add them to a .zip archive for easy restoration later using the muOS Backup Manager.

# Grab current date
DATE=$(date +%Y-%m-%d)

# Determine RetroArch Save Directory
RA_SAVEFILE_DIR=$(grep 'savefile_dir' /mnt/mmc/MUOS/retroarch/retroarch.cfg | cut -d '"' -f 2)
RA_SAVESTATE_DIR=$(grep 'savestate_dir' /mnt/mmc/MUOS/retroarch/retroarch.cfg | cut -d '"' -f 2)

# Remove ~ from modified RA save paths
RA_SAVEFILE_DIR=$(echo "$RA_SAVEFILE_DIR" | sed 's/~//')
RA_SAVESTATE_DIR=$(echo "$RA_SAVESTATE_DIR" | sed 's/~//')

# Set RetroArch save source directories
if [ "$RA_SAVEFILE_DIR" = ":/save/file" ]; then
    MUOS_SAVEFILE_DIR="/mnt/mmc/MUOS/save/file"
else
    MUOS_SAVEFILE_DIR="$RA_SAVEFILE_DIR"
fi

if [ "$RA_SAVESTATE_DIR" = ":/save/state" ]; then
    MUOS_SAVESTATE_DIR="/mnt/mmc/MUOS/save/state"
else
    MUOS_SAVESTATE_DIR="$RA_SAVESTATE_DIR"
fi

# Define additional source directories
PPSSPP_SAVE_DIR="/mnt/mmc/.config"

# Set destination file based on priority
# USB -> SD2 -> SD1
if grep -m 1 "sda1" /proc/partitions > /dev/null; then
    mkdir -p "/mnt/usb/BACKUP/"
    DEST_DIR="/mnt/usb/BACKUP"
elif grep -m 1 "mmcblk1p1" /proc/partitions > /dev/null; then
    mkdir -p "/mnt/sdcard/BACKUP/"
    DEST_DIR="/mnt/sdcard/BACKUP"
else
    DEST_DIR="/mnt/mmc/BACKUP"
fi


DEST_FILE="$DEST_DIR/Save-$DATE.zip"

# Change to root so we capture full path in .zip
cd /

# Create the backup
zip -ru9 "$DEST_FILE" "$MUOS_SAVEFILE_DIR" "$MUOS_SAVESTATE_DIR" "$PPSSPP_SAVE_DIR"
