#!/bin/sh
# backup.sh - A script to backup files from MUOS devices
# This script reads a manifest file to determine which files to back up,
# where to back them up, and whether to do it in individual or batch mode.
# It supports both individual backups and batch processing of multiple files.

LOGFILE="/tmp/muxbackup.log"
exec > >(tee -a "$LOGFILE") 2>&1

. /opt/muos/script/var/func.sh
FRONTEND stop

SET_VAR "system" "foreground_process" "muxbackup"

# VARIABLES
MANIFEST_FILE="/tmp/muxbackup_manifest.txt"
ERROR_FLAG=0

# START SCRIPT
echo "Starting backup script at $(date +"%Y-%m-%d %H:%M:%S")"

# Check if manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
	echo "Manifest file not found: $MANIFEST_FILE"
	ERROR_FLAG=1
elif ! read -r SRC_MODE DEST_MNT <"$MANIFEST_FILE"; then
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

BACKUP_FOLDER="BACKUP"

SD1="$(GET_VAR "device" "storage/rom/mount")"
SD2="$(GET_VAR "device" "storage/sdcard/mount")"
USB="$(GET_VAR "device" "storage/usb/mount")"

if [ "$ERROR_FLAG" -ne 1 ]; then
	case "$DEST_MNT" in
		SD1) DEST_PATH="$SD1/$BACKUP_FOLDER" ;;
		SD2) DEST_PATH="$SD2/$BACKUP_FOLDER" ;;
		USB) DEST_PATH="$USB/$BACKUP_FOLDER" ;;
	esac

	# Check if destination exists
	if [ ! -d "$DEST_PATH" ]; then
		echo "Destination path does not exist: $DEST_PATH"
		ERROR_FLAG=1
	fi
fi

LINE_NUM=0

if [ "$ERROR_FLAG" -ne 1 ]; then
	cd /
	# Read the manifest file line by line
	while read -r SRC_MNT SRC_SHORTNAME SRC_SUFFIX; do
		SRC_PATH=""

		LINE_NUM=$((LINE_NUM + 1))

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

		echo "$SRC_SHORTNAME: $SRC_MNT/$SRC_SUFFIX"
		# Handle special cases
		if [ "$SRC_SHORTNAME" = "External" ] || [ "$SRC_SHORTNAME" = "MuosConfig" ]; then

			if [ "$SRC_SHORTNAME" = "External" ]; then
				# Define Dreamcast VMU source
				if [ -d "/run/muos/storage/bios/dc" ]; then
					if [ -f "/run/muos/storage/bios/dc/dc_nvmem.bin" ]; then
						DREAMCAST_NVMEM="/run/muos/storage/bios/dc/dc_nvmem.bin"
					fi
					VMU_SAVES=$(ls "/run/muos/storage/bios/dc/vmu_save_"* 2>/dev/null)
					if [ -n "$VMU_SAVES" ]; then
						DREAMCAST_VMU="/run/muos/storage/bios/dc/vmu_save_"*
					fi
				fi

				# Define DraStic source directories
				if [ -d "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic" ]; then
					DRASTIC_SAVE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic/backup"
					DRASTIC_SAVESTATE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic/savestates"
				else
					DRASTIC_SAVE_DIR=""
					DRASTIC_SAVESTATE_DIR=""
				fi

				# Define additional RA source directories
				if [ -d "$(GET_VAR "device" "storage/rom/mount")/.config" ]; then
					PPSSPP_RA_SAVE_DIR="$(GET_VAR "device" "storage/rom/mount")/.config"
				else
					PPSSPP_RA_SAVE_DIR=""
				fi

				if [ -f "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/pico8/pico8_64" ]; then
					PICO8_64="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/pico8/pico8_64"
				else
					PICO8_64=""
				fi

				if [ -f "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/pico8/pico8_dyn" ]; then
					PICO8_DYN="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/pico8/pico8_dyn"
				else
					PICO8_DYN=""
				fi

				if [ -f "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/pico8/pico8.dat" ]; then
					PICO8_DAT="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/pico8/pico8.dat"
				else
					PICO8_DAT=""
				fi

				# Capture external emulator files
				TO_BACKUP="
                $PICO8_64
                $PICO8_DYN
                $PICO8_DAT
                $PPSSPP_RA_SAVE_DIR
                $DRASTIC_SAVE_DIR
                $DRASTIC_SAVESTATE_DIR
                $DREAMCAST_NVMEM
                $DREAMCAST_VMU
                "
			elif [ "$SRC_SHORTNAME" = "MuosConfig" ]; then
				if [ -d "/opt/muos/config" ]; then
					MUOS_CONFIG_DIR="/opt/muos/config"
				else
					MUOS_CONFIG_DIR=""
				fi

				# Capture muOS configuration files
				TO_BACKUP="
                $MUOS_CONFIG_DIR
                "
			fi

			SRC_PATHS=$(mktemp)

			for BACKUP in $TO_BACKUP; do
				if [ -e "$BACKUP" ]; then
					echo "$BACKUP" >>"$SRC_PATHS"
					echo "Found: $BACKUP"
				fi
			done

			if [ -s "$SRC_PATHS" ]; then
				SRC_PATH=""
				while IFS= read -r FILE; do
					SRC_PATH="$SRC_PATH $FILE"
				done <"$SRC_PATHS"
				SRC_PATH=$(echo "$SRC_PATH" | sed 's/^ *//')
			fi

			rm "$SRC_PATHS"

			if [ -z "$SRC_PATH" ]; then
				echo "No source files found for $SRC_SHORTNAME"
				continue
			fi
		else
			# Validate and assign source mount point
			case "$SRC_MNT" in
				SD1) SRC_MNT_PATH="$SD1" ;;
				SD2) SRC_MNT_PATH="$SD2" ;;
				USB) SRC_MNT_PATH="$USB" ;;
				*)
					echo "Invalid SRC_MNT: $SRC_MNT at line $LINE_NUM"
					ERROR_FLAG=1
					break
					;;
			esac

			SRC_PATH="$SRC_MNT_PATH/$SRC_SUFFIX"

			# Check if source path exists
			if [ ! -e "$SRC_PATH" ]; then
				echo "Source path not found: $SRC_PATH"
				ERROR_FLAG=1
				break
			fi
		fi

		if [ "$ERROR_FLAG" -eq 0 ]; then
			DEST_AVAIL=$(df -k "$DEST_PATH" | tail -1 | awk '{print $4}')

			if [ "$SRC_SHORTNAME" = "External" ] || [ "$SRC_SHORTNAME" = "MuosConfig" ]; then
				SRC_SIZE=0
				for FILE in $SRC_PATH; do
					if [ -e "$FILE" ]; then
						FILE_SIZE=$(du -sk "$FILE" | awk '{print $1}')
						SRC_SIZE=$((SRC_SIZE + FILE_SIZE))
						echo "Found source: $FILE ($FILE_SIZE KB)"
					fi
				done
			else
				# Get source path size
				SRC_SIZE=$(du -sk "$SRC_PATH" | awk '{print $1}')
			fi

			echo "Total size of source files: $SRC_SIZE KB"

			if [ -z "$SRC_SIZE" ]; then
				echo "Error: SRC_SIZE is not set for $SRC_SHORTNAME"
				ERROR_FLAG=1
				break
			elif [ -z "$DEST_AVAIL" ]; then
				echo "Error: DEST_AVAIL is not set for $SRC_SHORTNAME"
				ERROR_FLAG=1
				break
			elif [ "$SRC_SIZE" -gt "$DEST_AVAIL" ]; then
				echo "Not enough space for $SRC_SHORTNAME ($SRC_SIZE KB needed, $DEST_AVAIL KB available)"
				ERROR_FLAG=1
				break
			fi

			# Use -ru0 for already compressed packages, -ru9 for directories, -u9 for files
			if [ "$SRC_SHORTNAME" = "CataloguePkg" ] || [ "$SRC_SHORTNAME" = "ConfigPkg" ] || [ "$SRC_SHORTNAME" = "BootlogoPkg" ]; then
				ZIP_FLAGS="-ru0"
			elif [ "$SRC_SHORTNAME" = "External" ] || [ "$SRC_SHORTNAME" = "MuosConfig" ] || [ -d "$SRC_PATH" ]; then
				ZIP_FLAGS="-ru9"
			elif [ -f "$SRC_PATH" ]; then
				ZIP_FLAGS="-u9"
			else
				echo "Source path is neither file nor directory: $SRC_PATH"
				ERROR_FLAG=1
				break
			fi

			DEST_FILE="${DEST_PATH}/muOS-${SRC_SHORTNAME}-$(date +%Y%m%d-%H%M).muxzip"

			echo "Creating archive for $SRC_SHORTNAME at $DEST_FILE"
			if [ "$SRC_SHORTNAME" = "External" ] || [ "$SRC_SHORTNAME" = "MuosConfig" ]; then

				echo "zip $ZIP_FLAGS "\"$DEST_FILE\"" $SRC_PATH"
				# Use eval to expand the file list for zip in POSIX shell
				if ! eval zip $ZIP_FLAGS "\"$DEST_FILE\"" $SRC_PATH; then
					echo "Failed to create archive for external sources"
					ERROR_FLAG=1
					break
				fi
			elif ! zip $ZIP_FLAGS "$DEST_FILE" "$SRC_PATH"; then
				echo "Failed to create archive for $SRC_PATH"
				ERROR_FLAG=1
				break
			fi
			echo "Created archive for $SRC_SHORTNAME at $DEST_FILE"
		fi
	done <"$MANIFEST_FILE"
fi

if [ "$ERROR_FLAG" -ne 0 ]; then
	echo "An error occurred during the backup process."
else
	echo "Backup completed successfully."
fi

# Remove the manifest file
if [ -f "$MANIFEST_FILE" ]; then
	rm -f "$MANIFEST_FILE"
fi

echo "Finished backup script at $(date +"%Y-%m-%d %H:%M:%S")"
echo "Sync Filesystem"
sync

/opt/muos/bin/toybox sleep 5
FRONTEND start backup

SET_VAR "system" "foreground_process" "muxfrontend"

exit 0
