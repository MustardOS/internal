#!/bin/sh
# HELP: Restore the default friendly name files
# ICON: sdcard

. /opt/muos/script/var/func.sh

# Define Directories
USER_CONF="/run/muos/storage/info/name/"
DEFAULT_CONF="/opt/muos/default/MUOS/info/name/"

# Define log file
LOG_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/task"
LOG_FILE="$LOG_DIR/restore_friendly_names__$(date +'%Y_%m_%d__%H_%M').log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Redirect stdout and stderr to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

pkill -STOP muxtask

# Function to restore backup and verify
sync_and_verify() {
    rsync --archive --checksum --delete --progress "$DEFAULT_CONF" "$USER_CONF"
    diff -r "$DEFAULT_CONF" "$USER_CONF"
}

# Initial Restore
sync_and_verify

# Loop with a retry limit
MAX_TRY=3
TRY_COUNT=0

while ! sync_and_verify && [ $TRY_COUNT -lt $MAX_TRY ]; do
    echo "Differences found between default and local. Retrying restore... Attempt $((TRY_COUNT + 1)) of $MAX_TRY"
    sync_and_verify
    TRY_COUNT=$((TRY_COUNT + 1))
done

if [ $TRY_COUNT -eq $MAX_TRY ]; then
    echo "Restore failed after $MAX_TRY attempts."
else
    echo "Files successfully restored!"
fi

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
