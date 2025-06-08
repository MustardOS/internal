#!/bin/sh
# muxbackup.sh - A script to backup files from MUOS devices
# This script reads a manifest file to determine which files to back up,
# where to back them up, and whether to do it in individual or batch mode.
# It supports both individual backups and batch processing of multiple files.

LOGFILE="/tmp/muxbackup.log"
exec > >(tee -a "$LOGFILE") 2>&1

. /opt/muos/script/var/func.sh
FRONTEND stop

# VARIABLES
MANIFEST_FILE="/tmp/muxbackup_manifest.txt"
BACKUP_FOLDER="BACKUP"
TOTAL_SIZE=0
SD1="$(GET_VAR "device" "storage/rom/mount")"
SD2="$(GET_VAR "device" "storage/sdcard/mount")"
USB="$(GET_VAR "device" "storage/usb/mount")"
ERROR_FLAG=0
LINE_NUM=0

# START SCRIPT
echo "Starting muxbackup script at $(date +"%Y-%m-%d %H:%M:%S")"

# Check if manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Manifest file not found: $MANIFEST_FILE"
    ERROR_FLAG=1
elif ! read -r SRC_MODE DEST_MNT < "$MANIFEST_FILE"; then
    echo "Failed to read manifest header from $MANIFEST_FILE"
    ERROR_FLAG=1
# Read the first line of the manifest file to get SRC_MODE and DEST_MNT
elif [ -z "$SRC_MODE" ] || [ -z "$DEST_MNT" ]; then
    echo "Invalid manifest header format. Expected: SRC_MODE DEST_MNT"
    ERROR_FLAG=1
elif [ "$SRC_MODE" != "INDIVIDUAL" ] && [ "$SRC_MODE" != "BATCH" ]; then
    echo "Invalid SRC_MODE in manifest: $SRC_MODE"
    ERROR_FLAG=1
elif [ "$DEST_MNT" != "SD1" ] && [ "$DEST_MNT" != "SD2" ] && [ "$DEST_MNT" != "USB" ]; then
    echo "Invalid DEST_MNT in manifest: $DEST_MNT"
    ERROR_FLAG=1
fi

if [ "$ERROR_FLAG" -ne 1 ]; then
    if [ "$SRC_MODE" = "BATCH" ]; then
        BACKUP_FOLDER="BACKUP/$(date +"%Y%m%d_%H%M")"
    fi

    case "$DEST_MNT" in
        SD1) DEST_PATH="$SD1/$BACKUP_FOLDER";;
        SD2) DEST_PATH="$SD2/$BACKUP_FOLDER";;
        USB) DEST_PATH="$USB/$BACKUP_FOLDER";;
    esac

    # Prepare destination
    if [ ! -d "$DEST_PATH" ]; then
        mkdir -p "$DEST_PATH"
    fi
fi

if [ "$ERROR_FLAG" -ne 1 ]; then
	cd /
    # Read the manifest file line by line
    while read -r SRC_MNT SRC_SHORTNAME SRC_SUFFIX; do
        
        LINE_NUM=$((LINE_NUM+1))

        # Skip header
        if [ $LINE_NUM -eq 1 ]; then
            continue
        elif [ "$ERROR_FLAG" -ne 0 ]; then
            break
        # Validate line format
        elif [ -z "$SRC_MNT" ] || [ -z "$SRC_SHORTNAME" ] || [ -z "$SRC_SUFFIX" ]; then
            echo "Invalid line $LINE_NUM in manifest: $SRC_MNT $SRC_SHORTNAME $SRC_SUFFIX"
            ERROR_FLAG=1
            break
        fi

        # Validate and assign source mount point
        case "$SRC_MNT" in
            SD1) SRC_MNT_PATH="$SD1";;
            SD2) SRC_MNT_PATH="$SD2";;
            USB) SRC_MNT_PATH="$USB";;
            *) echo "Invalid SRC_MNT: $SRC_MNT at line $LINE_NUM"; ERROR_FLAG=1; break;;
        esac

        SRC_PATH="$SRC_MNT_PATH/$SRC_SUFFIX"

        # Check if source path exists
        if [ ! -e "$SRC_PATH" ]; then
            echo "Source path not found: $SRC_PATH"
            ERROR_FLAG=1
            break
        fi
        
        # Get source path size
        SRC_SIZE=$(du -sk "$SRC_PATH" | awk '{print $1}')
        DEST_AVAIL=$(df -k "$DEST_PATH" | tail -1 | awk '{print $4}')

        if [ $SRC_SIZE -gt $DEST_AVAIL ]; then
            echo "Not enough space for $SRC_SHORTNAME ($SRC_SIZE KB needed, $DEST_AVAIL KB available)"
            ERROR_FLAG=1
            break
        fi

        # Use -ru0 for already compressed packages, -ru9 for directories, -u9 for files
        if [ "$SRC_SHORTNAME" = "CataloguePkg" ] || [ "$SRC_SHORTNAME" = "ConfigPkg" ] || ["$SRC_SHORTNAME" = "BootlogoPkg"]; then
            ZIP_FLAGS="-ru0"
        elif [ -d "$SRC_PATH" ]; then
            ZIP_FLAGS="-ru9"
        elif [ -f "$SRC_PATH" ]; then
            ZIP_FLAGS="-u9"
        else
            echo "Source path is neither file nor directory: $SRC_PATH"
            ERROR_FLAG=1
            break
        fi
        
        DEST_FILE="$DEST_PATH/$SRC_SHORTNAME$(date +"_%Y%m%d_%H%M").muxbak"
        
        echo "Creating archive for $SRC_SHORTNAME at $DEST_FILE"
        if ! zip $ZIP_FLAGS "$DEST_FILE" "$SRC_PATH"; then
            echo "Failed to create archive for $SRC_PATH"
            ERROR_FLAG=1
            break
        fi
        echo "Created archive for $SRC_SHORTNAME at $DEST_FILE"


    done < "$MANIFEST_FILE"
fi

if [ "$ERROR_FLAG" -ne 0 ]; then
    echo "An error occurred during the backup process."
else
    echo "Backup completed successfully."
fi

# Remove temporary files if they exist
if [ ! -z "$TMP_PATH" ]  && [ -d "$TMP_PATH" ]; then
    echo "Removing temporary files from $TMP_PATH"
    rm -rf "$TMP_PATH"
fi

# Remove the manifest file
if [ -f "$MANIFEST_FILE" ]; then
    rm -f "$MANIFEST_FILE"
fi

echo "Finished muxbackup script at $(date +"%Y-%m-%d %H:%M:%S")"
echo "Sync Filesystem"
sync

/opt/muos/bin/toybox sleep 5
FRONTEND start backup
exit 0
