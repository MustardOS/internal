#!/bin/sh
# HELP: Backup the active theme to a zip file with a timestamped name.
# ICON: backup

# Define the source directory to back up
SOURCE_DIR="/run/muos/storage/theme/active"

# Define the destination directory for the backup
DEST_DIR="/run/muos/storage/theme"

# Generate the timestamp for the backup filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Construct the destination file name
DEST_FILE="$DEST_DIR/active-$TIMESTAMP.zip"

# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Navigate to the source directory and zip its contents at the root level
echo "Backing up contents of $SOURCE_DIR to $DEST_FILE"
cd "$SOURCE_DIR" || exit 1
zip -r "$DEST_FILE" ./*

echo "Backup complete: $DEST_FILE"

# Synchronize filesystem to ensure all changes are saved
echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

exit 0