#!/bin/sh

. /opt/muos/script/var/func.sh

FRONTEND stop

THROBBER_WAIT="${THROBBER_WAIT:-1}"
RSYNC_PID=""

SLEEP_AND_GO() {
	[ -n "$RSYNC_PID" ] && kill -0 "$RSYNC_PID" 2>/dev/null && kill "$RSYNC_PID" 2>/dev/null
	sleep 5
	FRONTEND start storage
	exit "$1"
}

trap 'printf "\nInterrupted - Aborting\n"; SLEEP_AND_GO 130' INT TERM HUP

THROBBER() {
	while kill -0 "$1" 2>/dev/null; do
		printf "."
		sleep "$THROBBER_WAIT"
	done
}

IS_UINT() {
	case "$1" in
		'' | *[!0-9]*) return 1 ;;
		*) return 0 ;;
	esac
}

M_PATH="$1"

if [ -z "$M_PATH" ]; then
	printf "Usage: %s <relative-path>\n" "$0"
	SLEEP_AND_GO 1
fi

case "$M_PATH" in
	/* | *..*)
		printf "Invalid path '%s' - must be relative and contain no '..'\n" "$M_PATH"
		SLEEP_AND_GO 1
		;;
esac

SD1_ROOT="$(GET_VAR "device" "storage/rom/mount")"
SD2_ROOT="$(GET_VAR "device" "storage/sdcard/mount")"

SD1="$SD1_ROOT/$M_PATH"
SD2="$SD2_ROOT/$M_PATH"

RSYNC_LOG="$SD1_ROOT/MUOS/log/storage_sync.log"

# Check if SD2 is mounted - ensuring the source is available
SD_DEVICE="$(GET_VAR "device" "storage/sdcard/dev")$(GET_VAR "device" "storage/sdcard/sep")$(GET_VAR "device" "storage/sdcard/num")"
if grep -q -m 1 "$SD_DEVICE" /proc/partitions; then
	printf "SD2 has been detected\nSyncing '%s' from SD2\n" "$M_PATH"
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

SD2_INFO="$(find "$SD2" -type f -exec ls -ln {} + 2>/dev/null |
	awk 'BEGIN { c = 0; b = 0 }
	     /^-/   { c++; b += $5 }
	     END    { printf "%d %d", c, int((b + 1023) / 1024) }')"

FILE_COUNT="${SD2_INFO% *}"

SD2_SIZE="${SD2_INFO#* }"
SD1_SPACE="$(df -k "$SD1" | awk 'NR==2 { print $4; exit }')"

if ! IS_UINT "$SD2_SIZE"; then
	printf "Unable to determine size of '%s' - Aborting\n" "$SD2"
	SLEEP_AND_GO 1
fi

if ! IS_UINT "$SD1_SPACE"; then
	printf "Unable to determine available space on '%s' - Aborting\n" "$SD1"
	SLEEP_AND_GO 1
fi

# Require a 5% safety margin. Doubly important here: SD1 is the boot card,
# and filling it can prevent the frontend from starting again.
SD2_NEED=$((SD2_SIZE + SD2_SIZE / 20))
if [ "$SD1_SPACE" -lt "$SD2_NEED" ]; then
	printf "Not enough space on SD1 to sync '%s'\n\tRequired: %s KB (incl. 5%% margin)\n\tAvailable: %s KB\n" \
		"$M_PATH" "$SD2_NEED" "$SD1_SPACE"
	SLEEP_AND_GO 1
fi

printf "Found %s files (%s KB)\n\n" "$FILE_COUNT" "$SD2_SIZE"

RSYNC_LOG_DIR="${RSYNC_LOG%/*}"
mkdir -p "$RSYNC_LOG_DIR" || {
	printf "Failed to create log directory '%s' - Aborting\n" "$RSYNC_LOG_DIR"
	SLEEP_AND_GO 1
}
: >"$RSYNC_LOG" || {
	printf "Failed to write log file '%s' - Aborting\n" "$RSYNC_LOG"
	SLEEP_AND_GO 1
}

printf "Syncing Files"

rsync --archive --itemize-changes --log-file="$RSYNC_LOG" "$SD2/" "$SD1/" >/dev/null 2>&1 &
RSYNC_PID="$!"

THROBBER "$RSYNC_PID"
wait "$RSYNC_PID"
RSYNC_STATUS="$?"
RSYNC_PID=""

printf "\n\n"

if [ "$RSYNC_STATUS" -ne 0 ]; then
	printf "Sync failed with status %s - See '%s'\n" "$RSYNC_STATUS" "$RSYNC_LOG"
	SLEEP_AND_GO 1
fi

# Sync and sleep for a bit
printf "Sync Filesystem\n"
sync

printf "All Done!\n"
SLEEP_AND_GO 0
