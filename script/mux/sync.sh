#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh
. /opt/muos/script/var/transfer.sh

LOG_INFO "$0" 0 "SYNC" "Storage sync started"

TASK_IS_NATIVE || FRONTEND stop

SLEEP_AND_GO() {
	TRANSFER_ABORT
	LOG_INFO "$0" 0 "SYNC" "$(printf "Exiting with code %s" "$1")"
	TASK_IS_NATIVE || {
		sleep 5
		FRONTEND start storage
	}
	exit "$1"
}

trap 'LOG_WARN "$0" 0 "SYNC" "Interrupted by signal"; TASK_ERROR "interrupted" "Interrupted - aborting."; SLEEP_AND_GO 130' INT TERM HUP

SD1_ROOT="$(GET_VAR "device" "storage/rom/mount")"
SD2_ROOT="$(GET_VAR "device" "storage/sdcard/mount")"

LOG_INFO "$0" 0 "SYNC" "$(printf "Syncing from secondary storage: %s" "$*")"

TRANSFER_RUN "SYNC" "storage_sync.log" "$SD2_ROOT" "$SD1_ROOT" "$@" || SLEEP_AND_GO 1

TASK_STATUS "Sync Filesystem"
sync

LOG_SUCCESS "$0" 0 "SYNC" "$(printf "Sync of '%s' completed" "$TRANSFER_LIST")"
TASK_COMPLETE "Sync completed"
SLEEP_AND_GO 0
