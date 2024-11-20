#!/bin/sh
# HELP: Backup the active theme to a zip file with a timestamped name.
# ICON: backup

# Define the source directory to back up
SOURCE_DIR="/run/muos/storage/theme/active"

# Define the destination directory for the backup
DEST_DIR="/run/muos/storage/theme"

# Generate the timestamp for the backup filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Check if theme_name.txt exists and read the base theme name
if [ -f "$SOURCE_DIR/theme_name.txt" ]; then
    THEME_NAME_FILE="theme_name.txt"
    BASE_THEME_NAME=$(sed -n '1p' "$SOURCE_DIR/$THEME_NAME_FILE")
    echo "$BASE_THEME_NAME is the base theme name"
else
    BASE_THEME_NAME="active"
    echo "theme_name.txt not found. Using default theme name: $BASE_THEME_NAME"
fi

echo "$BASE_THEME_NAME is the base theme name"

# Construct the destination file name
DEST_FILE="$DEST_DIR/$BASE_THEME_NAME-$TIMESTAMP.zip"

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