#!/bin/sh

# Suspend the muxbackup program
pkill -STOP muxbackup

# Backup script designed to grab all artwork and add it to a .zip archive for easy restoration later using the muOS Archive Manager.

# Define message block
MESSAGE() {
    _TITLE=$1
    _MESSAGE=$2
    _FORM=$(cat <<EOF
$_TITLE

$_MESSAGE
EOF
    )
    /opt/muos/extra/muxstart "$_FORM" && sleep "$3"
}

# Start message box test
TITLE="Backing up Artwork (Catalogue)"
CONTENT="If you can read this, Artwork (Catalogue) should be backing up!"
MESSAGE "$TITLE" "$CONTENT" 3

# Grab current date
DATE=$(date +%Y-%m-%d)

# muOS Catalogue Directory
MUOS_CAT_DIR="/mnt/mmc/MUOS/info/catalogue"

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

DEST_FILE="$DEST_DIR/Artwork-$DATE.zip"

# Change to root so we capture full path in .zip
cd /

# Create the backup
zip -ru9 "$DEST_FILE" "$MUOS_CAT_DIR"

# Sync filesystem just-in-case :)
sync

# Resume the muxbackup program
pkill -CONT muxbackup