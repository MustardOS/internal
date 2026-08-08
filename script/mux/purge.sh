#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

LOG_INFO "$0" 0 "PURGE" "Storage purge started"

TASK_IS_NATIVE || FRONTEND stop

SLEEP_AND_GO() {
	LOG_INFO "$0" 0 "PURGE" "$(printf "Exiting with code %s" "$1")"
	TASK_IS_NATIVE || {
		sleep 5
		FRONTEND start storage
	}
	exit "$1"
}

trap 'LOG_WARN "$0" 0 "PURGE" "Interrupted by signal"; TASK_ERROR "interrupted" "Interrupted - aborting."; SLEEP_AND_GO 130' INT TERM HUP

DO_SYNC=0
if [ "$1" = "--sync" ]; then
	DO_SYNC=1
	shift
fi

if [ "$#" -eq 0 ]; then
	LOG_ERROR "$0" 0 "PURGE" "No path provided"
	TASK_ERROR "bad_arguments" "$(printf "Usage: %s [--sync] <relative-path>..." "$0")"
	SLEEP_AND_GO 1
fi

for M_PATH in "$@"; do
	case "$M_PATH" in
		/* | *..*)
			LOG_ERROR "$0" 0 "PURGE" "$(printf "Invalid path: '%s'" "$M_PATH")"
			TASK_ERROR "bad_path" "$(printf "Invalid path '%s', it must be relative" "$M_PATH")"
			SLEEP_AND_GO 1
			;;
	esac
done

LOG_INFO "$0" 0 "PURGE" "$(printf "Purging paths: %s" "$*")"

if [ "$DO_SYNC" -eq 1 ]; then
	LOG_INFO "$0" 0 "PURGE" "Syncing before purge"

	if ! /opt/muos/script/mux/sync.sh "$@"; then
		LOG_ERROR "$0" 0 "PURGE" "Sync failed, nothing was purged"
		TASK_COMPLETE "Sync failed, so nothing was purged"
		SLEEP_AND_GO 1
	fi
fi

SD2_ROOT="$(GET_VAR "device" "storage/sdcard/mount")"

if [ -z "$SD2_ROOT" ] || ! grep -qs " $SD2_ROOT " /proc/mounts; then
	LOG_ERROR "$0" 0 "PURGE" "Secondary storage not detected"
	TASK_ERROR "no_sdcard" "Secondary storage was not detected."
	SLEEP_AND_GO 1
fi

TOTAL="$#"
DONE_COUNT=0
REMOVED=0

TASK_STATUS "Removing from Secondary Storage"

for M_PATH in "$@"; do
	SD2="$SD2_ROOT/$M_PATH"

	TASK_DETAIL "$M_PATH"
	TASK_PROGRESS "$DONE_COUNT" "$TOTAL"

	if [ -d "$SD2" ]; then
		if ! rm -rf "${SD2:?}"; then
			LOG_ERROR "$0" 0 "PURGE" "$(printf "Failed to remove '%s'" "$SD2")"
			TASK_ERROR "remove_failed" "$(printf "Could not remove '%s'" "$SD2")"
			SLEEP_AND_GO 1
		fi
		REMOVED=$((REMOVED + 1))
	else
		LOG_INFO "$0" 0 "PURGE" "$(printf "Nothing to purge at '%s'" "$SD2")"
	fi

	DONE_COUNT=$((DONE_COUNT + 1))
done

if [ "$REMOVED" -eq 0 ]; then
	LOG_INFO "$0" 0 "PURGE" "Nothing was on secondary storage"
	TASK_COMPLETE "Nothing was on secondary storage"
	SLEEP_AND_GO 0
fi

TASK_STATUS "Rebinding Storage Paths"
TASK_PROGRESS "$TOTAL" "$TOTAL"

/opt/muos/script/device/bind.sh >/dev/null

TASK_STATUS "Sync Filesystem"

sync

LOG_SUCCESS "$0" 0 "PURGE" "$(printf "Purge of %s completed" "$*")"
TASK_COMPLETE "Purge completed"
SLEEP_AND_GO 0
