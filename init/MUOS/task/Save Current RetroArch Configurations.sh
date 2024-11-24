#!/bin/sh
# HELP: Backup the active retroarch configuration set to a zip file with a timestamped name.
# ICON: backup

# Define the source directory to back up
SOURCE_DIR="/run/muos/storage/info/config"

# Define the destination directory for the backup
DEST_DIR="/run/muos/storage/package/config"

# Generate the timestamp for the backup filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Check if config_name.txt exists and read the base config set name
if [ -f "$SOURCE_DIR/config_name.txt" ]; then
	CONFIG_NAME_FILE="config_name.txt"
	BASE_CONFIG_NAME=$(sed -n '1p' "$SOURCE_DIR/$CONFIG_NAME_FILE")
	echo "$BASE_CONFIG_NAME is the base config set name"
else
	BASE_CONFIG_NAME="current_retroarch_config"
	echo "config_name.txt not found. Using default retroarch configuration set name: $BASE_CONFIG_NAME"
fi

echo "$BASE_CONFIG_NAME is the base retroarch configuration set name"

# Construct the destination file name
DEST_FILE="$DEST_DIR/$BASE_CONFIG_NAME-$TIMESTAMP.zip"

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
