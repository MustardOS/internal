#!/bin/sh
# HELP: Backup the active catalogue set to a zip file with a timestamped name.
# ICON: backup

# Define the source directory to back up
SOURCE_DIR="/run/muos/storage/info/catalogue"

# Define the destination directory for the backup
DEST_DIR="/run/muos/storage/package/catalogue"

# Generate the timestamp for the backup filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Check if catalogue_name.txt exists and read the base catalogue set name
if [ -f "$SOURCE_DIR/catalogue_name.txt" ]; then
	CATALOGUE_NAME_FILE="catalogue_name.txt"
	BASE_CATALOGUE_NAME=$(sed -n '1p' "$SOURCE_DIR/$CATALOGUE_NAME_FILE")
	echo "$BASE_CATALOGUE_NAME is the base catalogue set name"
else
	BASE_CATALOGUE_NAME="current_catalogue"
	echo "catalogue_name.txt not found. Using default catalogue set name: $BASE_CATALOGUE_NAME"
fi

echo "$BASE_CATALOGUE_NAME is the base catalogue set name"

# Construct the destination file name
DEST_FILE="$DEST_DIR/$BASE_CATALOGUE_NAME-$TIMESTAMP.zip"

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
