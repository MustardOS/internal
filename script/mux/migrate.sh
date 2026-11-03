#!/bin/sh

. /opt/muos/script/var/log.sh
. /opt/muos/script/var/service.sh
. /opt/muos/script/var/ui.sh
. /opt/muos/script/var/transfer.sh

if [ "${MUOS_STORAGE_LOCKED:-0}" -eq 0 ]; then
	MUOS_STORAGE_LOCKED=1 /usr/bin/flock -E 75 -w 60 "$MUOS_RUN_DIR/storage-write.lock" "$0" "$@"
	LOCK_STATUS=$?
	if [ "$LOCK_STATUS" -eq 75 ]; then
		TASK_ERROR "storage_busy" "Storage is busy with another catalogue or migration operation."
	fi
	exit "$LOCK_STATUS"
fi

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

TASK_STATUS "Sync Filesystem"
sync || {
	TASK_ERROR "sync_failed" "Copied data could not be synchronised."
	SLEEP_AND_GO 1
}

LOG_INFO "$0" 0 "MIGRATE" "Rebinding storage paths"
TASK_STATUS "Rebinding Storage Paths"

if ! /opt/muos/script/device/bind.sh down >/dev/null; then
	/opt/muos/script/device/bind.sh >/dev/null 2>&1
	TASK_ERROR "unbind_failed" "Existing storage paths could not be cleanly unbound."
	SLEEP_AND_GO 1
fi

if ! /opt/muos/script/device/bind.sh >/dev/null; then
	TASK_ERROR "bind_failed" "Migrated storage paths could not be rebound."
	SLEEP_AND_GO 1
fi

LOG_SUCCESS "$0" 0 "MIGRATE" "$(printf "Migration of '%s' completed" "$TRANSFER_LIST")"
TASK_COMPLETE "Migration completed"
SLEEP_AND_GO 0
