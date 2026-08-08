#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh
. /opt/muos/script/var/transfer.sh

LOG_INFO "$0" 0 "MIGRATE" "Storage migration started"

TASK_IS_NATIVE || FRONTEND stop

SLEEP_AND_GO() {
	TRANSFER_ABORT
	LOG_INFO "$0" 0 "MIGRATE" "$(printf "Exiting with code %s" "$1")"
	TASK_IS_NATIVE || {
		sleep 5
		FRONTEND start storage
	}
	exit "$1"
}

trap 'LOG_WARN "$0" 0 "MIGRATE" "Interrupted by signal"; TASK_ERROR "interrupted" "Interrupted - aborting."; SLEEP_AND_GO 130' INT TERM HUP

SD1_ROOT="$(GET_VAR "device" "storage/rom/mount")"
SD2_ROOT="$(GET_VAR "device" "storage/sdcard/mount")"

LOG_INFO "$0" 0 "MIGRATE" "$(printf "Migrating to secondary storage: %s" "$*")"

TRANSFER_RUN "MIGRATE" "storage_migrate.log" "$SD1_ROOT" "$SD2_ROOT" "$@" || SLEEP_AND_GO 1

LOG_INFO "$0" 0 "MIGRATE" "Rebinding storage paths"
TASK_STATUS "Rebinding Storage Paths"

/opt/muos/script/device/bind.sh >/dev/null

TASK_STATUS "Sync Filesystem"
sync

LOG_SUCCESS "$0" 0 "MIGRATE" "$(printf "Migration of '%s' completed" "$TRANSFER_LIST")"
TASK_COMPLETE "Migration completed"
SLEEP_AND_GO 0
