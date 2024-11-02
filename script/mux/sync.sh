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

RSYNC_LOG="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/storage_sync.log"

# Check if SD2 is mounted - ensuring the source is available
SD_DEVICE="$(GET_VAR "device" "storage/sdcard/dev")$(GET_VAR "device" "storage/sdcard/sep")$(GET_VAR "device" "storage/sdcard/num")"
if grep -m 1 "$SD_DEVICE" /proc/partitions >/dev/null; then
	printf "SD2 has been detected\nSyncing '%s' from SD2\n" "$1"
else
	printf "SD2 not detected - Aborting\n"
	SLEEP_AND_GO 1
fi

# Ensure SD2 exists
if [ ! -d "$SD2" ]; then
	printf "Source directory '%s' does not exist on SD2 - Aborting\n" "$SD2"
	SLEEP_AND_GO 1
fi

# Create SD1 if it doesn't exist - I mean it should but just in case!
if [ ! -d "$SD1" ]; then
	printf "Destination directory '%s' does not exist - Creating it...\n" "$SD1"
	mkdir -p "$SD1" || {
		printf "Failed to create '%s' - Aborting\n" "$SD1"
		SLEEP_AND_GO 1
	}
fi

# Calculate size of SD2 directory and available space on SD1
SD2_SIZE=$(du -sk "$SD2" | awk '{print $1}')
SD1_SPACE=$(df -k "$SD1" | tail -1 | awk '{print $4}')

# Verify that SD1_SPACE is a valid number just in case awk fucks up
if ! [ "$SD1_SPACE" -eq "$SD1_SPACE" ] 2>/dev/null; then
	printf "Unable to determine available space on '%s' - Aborting\n" "$SD1"
	SLEEP_AND_GO 1
fi

# Check if there is enough space
if [ "$SD1_SPACE" -lt "$SD2_SIZE" ]; then
	printf "Not enough space on SD1 to sync '%s'\n\tRequired: %s KB\n\tAvailable: %s KB\n" \
		"$M_PATH" "$SD2_SIZE" "$SD1_SPACE"
	SLEEP_AND_GO 1
fi

FILE_COUNT="$(find "$SD2" -type f | wc -l)"
printf "Found %s files\n" "$FILE_COUNT"

rsync --archive --ignore-times --itemize-changes --checksum --outbuf=L --log-file="$RSYNC_LOG" "$SD2/" "$SD1/" |
	grep --line-buffered '^>f' |
	/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null

# Sync and sleep for a bit
printf "Sync Filesystem\n"
sync

printf "All Done!\n"
SLEEP_AND_GO 0
