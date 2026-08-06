#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

LOG_INFO "$0" 0 "SYNC" "Storage sync started"

TASK_IS_NATIVE || FRONTEND stop

THROBBER_WAIT="${THROBBER_WAIT:-1}"
RSYNC_PID=""

SLEEP_AND_GO() {
	[ -n "$RSYNC_PID" ] && kill -0 "$RSYNC_PID" 2>/dev/null && kill "$RSYNC_PID" 2>/dev/null
	LOG_INFO "$0" 0 "SYNC" "$(printf "Exiting with code %s" "$1")"
	TASK_IS_NATIVE || {
		sleep 5
		FRONTEND start storage
	}
	exit "$1"
}

trap 'LOG_WARN "$0" 0 "SYNC" "Interrupted by signal"; TASK_ERROR "interrupted" "Interrupted - aborting."; SLEEP_AND_GO 130' INT TERM HUP

THROBBER() {
	while kill -0 "$1" 2>/dev/null; do
		if TASK_IS_NATIVE; then
			TASK_PROGRESS "$(wc -l <"$RSYNC_LOG" 2>/dev/null || printf 0)" "$FILE_COUNT"
		else
			printf "."
		fi
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
	LOG_ERROR "$0" 0 "SYNC" "No path provided"
	TASK_ERROR "bad_arguments" "$(printf "Usage: %s <relative-path>" "$0")"
	SLEEP_AND_GO 1
fi

case "$M_PATH" in
	/* | *..*)
		LOG_ERROR "$0" 0 "SYNC" "$(printf "Invalid path: '%s'" "$M_PATH")"
		TASK_ERROR "bad_path" "$(printf "Invalid path '%s', it must be relative" "$M_PATH")"
		SLEEP_AND_GO 1
		;;
esac

LOG_INFO "$0" 0 "SYNC" "$(printf "Syncing path: '%s'" "$M_PATH")"

SD1_ROOT="$(GET_VAR "device" "storage/rom/mount")"
SD2_ROOT="$(GET_VAR "device" "storage/sdcard/mount")"

SD1="$SD1_ROOT/$M_PATH"
SD2="$SD2_ROOT/$M_PATH"

RSYNC_LOG="$SD1_ROOT/MUOS/log/storage_sync.log"

# Check if SD2 is mounted - ensuring the source is available
SD_DEVICE="$(GET_VAR "device" "storage/sdcard/dev")$(GET_VAR "device" "storage/sdcard/sep")$(GET_VAR "device" "storage/sdcard/num")"
if grep -q -m 1 "$SD_DEVICE" /proc/partitions; then
	LOG_INFO "$0" 0 "SYNC" "$(printf "SD2 detected - syncing '%s' from SD2" "$M_PATH")"
	TASK_STATUS "SD2 has been detected"
	TASK_DETAIL "$(printf "Syncing '%s' from SD2" "$M_PATH")"
else
	LOG_ERROR "$0" 0 "SYNC" "SD2 not detected"
	TASK_ERROR "no_sdcard" "SD2 was not detected."
	SLEEP_AND_GO 1
fi

# Ensure SD2 exists
if [ ! -d "$SD2" ]; then
	LOG_ERROR "$0" 0 "SYNC" "$(printf "Source directory not found on SD2: '%s'" "$SD2")"
	TASK_ERROR "source_missing" "$(printf "Source directory '%s' does not exist" "$SD2")"
	SLEEP_AND_GO 1
fi

# Create SD1 if it doesn't exist - I mean it should but just in case!
if [ ! -d "$SD1" ]; then
	LOG_INFO "$0" 0 "SYNC" "$(printf "Creating destination directory: '%s'" "$SD1")"
	TASK_DETAIL "$(printf "Creating destination directory '%s'" "$SD1")"
	mkdir -p "$SD1" || {
		LOG_ERROR "$0" 0 "SYNC" "$(printf "Failed to create destination: '%s'" "$SD1")"
		TASK_ERROR "mkdir_failed" "$(printf "Could not create '%s'" "$SD1")"
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
	LOG_ERROR "$0" 0 "SYNC" "$(printf "Unable to determine size of '%s'" "$SD2")"
	TASK_ERROR "size_unknown" "$(printf "Could not determine the size of '%s'" "$SD2")"
	SLEEP_AND_GO 1
fi

if ! IS_UINT "$SD1_SPACE"; then
	LOG_ERROR "$0" 0 "SYNC" "$(printf "Unable to determine available space on '%s'" "$SD1")"
	TASK_ERROR "space_unknown" "$(printf "Could not determine free space on '%s'" "$SD1")"
	SLEEP_AND_GO 1
fi

# Require a 5% safety margin. Doubly important here: SD1 is the boot card,
# and filling it can prevent the frontend from starting again.
SD2_NEED=$((SD2_SIZE + SD2_SIZE / 20))
if [ "$SD1_SPACE" -lt "$SD2_NEED" ]; then
	LOG_ERROR "$0" 0 "SYNC" "$(printf "Insufficient space on SD1 - required: %s KB, available: %s KB" "$SD2_NEED" "$SD1_SPACE")"
	TASK_ERROR "no_space" "$(printf "Not enough space, %s KB needed but only %s KB free" "$SD2_NEED" "$SD1_SPACE")"
	SLEEP_AND_GO 1
fi

LOG_INFO "$0" 0 "SYNC" "$(printf "Found %s files (%s KB)" "$FILE_COUNT" "$SD2_SIZE")"
TASK_DETAIL "$(printf "Found %s files (%s KB)" "$FILE_COUNT" "$SD2_SIZE")"

RSYNC_LOG_DIR="${RSYNC_LOG%/*}"
mkdir -p "$RSYNC_LOG_DIR" || {
	TASK_ERROR "log_failed" "$(printf "Could not create the log directory '%s'" "$RSYNC_LOG_DIR")"
	SLEEP_AND_GO 1
}
: >"$RSYNC_LOG" || {
	TASK_ERROR "log_failed" "$(printf "Could not write the log file '%s'" "$RSYNC_LOG")"
	SLEEP_AND_GO 1
}

TASK_STATUS "Syncing Files"
LOG_INFO "$0" 0 "SYNC" "$(printf "Running rsync: '%s/' -> '%s/'" "$SD2" "$SD1")"

rsync --archive --itemize-changes --log-file="$RSYNC_LOG" "$SD2/" "$SD1/" >/dev/null 2>&1 &
RSYNC_PID="$!"

THROBBER "$RSYNC_PID"
wait "$RSYNC_PID"
RSYNC_STATUS="$?"
RSYNC_PID=""

if [ "$RSYNC_STATUS" -ne 0 ]; then
	LOG_ERROR "$0" 0 "SYNC" "$(printf "rsync failed with status %s - see '%s'" "$RSYNC_STATUS" "$RSYNC_LOG")"
	TASK_ERROR "rsync_failed" "$(printf "Sync failed with status %s, see '%s'" "$RSYNC_STATUS" "$RSYNC_LOG")"
	SLEEP_AND_GO 1
fi

# Sync and sleep for a bit
TASK_STATUS "Sync Filesystem"
sync

LOG_SUCCESS "$0" 0 "SYNC" "$(printf "Sync of '%s' completed" "$M_PATH")"
TASK_COMPLETE "Sync completed"
SLEEP_AND_GO 0
