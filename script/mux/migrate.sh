#!/bin/sh

. /opt/muos/script/var/func.sh

pkill -STOP muxstorage

SLEEP_AND_GO() {
	sleep 5
	pkill -CONT muxstorage
	exit "$1"
}

M_PATH="$1"

SD1="$(GET_VAR "device" "storage/rom/mount")/$M_PATH"
SD2="$(GET_VAR "device" "storage/sdcard/mount")/$M_PATH"

RSYNC_LOG="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/storage_migrate.log"

# Ensure SD1 exists - it should but just in case something fucks up
if [ ! -d "$SD1" ]; then
	printf "Source directory '%s' does not exist - Aborting\n" "$SD1"
	SLEEP_AND_GO 1
fi

# See if SD2 is mounted - lets do this early in case it is not mounted
SD_DEVICE="$(GET_VAR "device" "storage/sdcard/dev")$(GET_VAR "device" "storage/sdcard/sep")$(GET_VAR "device" "storage/sdcard/num")"
if grep -m 1 "$SD_DEVICE" /proc/partitions >/dev/null; then
	printf "SD2 has been detected\nMigrating '%s' to SD2\n" "$1"
else
	printf "SD2 not detected - Aborting\n"
	SLEEP_AND_GO 1
fi

# Create SD2 if it doesn't exist
if [ ! -d "$SD2" ]; then
	printf "Destination directory '%s' does not exist - Creating it...\n" "$SD2"
	mkdir -p "$SD2" || {
		printf "Failed to create '%s' - Aborting\n" "$SD2"
		SLEEP_AND_GO 1
	}
fi

# Calculate size of SD1 directory and available space on SD2
SD1_SIZE=$(du -sk "$SD1" | awk '{print $1}')
SD2_SPACE=$(df -k "$SD2" | tail -1 | awk '{print $4}')

# Verify that SD2_SPACE is a valid number just in case awk fucks up
if ! [ "$SD2_SPACE" -eq "$SD2_SPACE" ] 2>/dev/null; then
	printf "Unable to determine available space on '%s' - Aborting\n" "$SD2"
	SLEEP_AND_GO 1
fi

# Check if there is enough space
if [ "$SD2_SPACE" -lt "$SD1_SIZE" ]; then
	printf "Not enough space on SD2 to migrate '%s'\n\tRequired: %s KB\n\tAvailable: %s KB\n" \
		"$M_PATH" "$SD1_SIZE" "$SD2_SPACE"
	SLEEP_AND_GO 1
fi

FILE_COUNT="$(find "$SD1" -type f | wc -l)"
printf "Found %s files\n" "$FILE_COUNT"

rsync --archive --ignore-times --itemize-changes --checksum --outbuf=L --log-file="$RSYNC_LOG" "$SD1/" "$SD2/" |
	grep --line-buffered '^>f' |
	/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null

# Sync and sleep for a bit - time for a rest!
printf "Sync Filesystem\n"
sync

# Rebinding storage paths
printf "Rebinding Storage Paths\n"
/opt/muos/script/var/init/storage.sh >/dev/null

printf "All Done!\n"
SLEEP_AND_GO 0
