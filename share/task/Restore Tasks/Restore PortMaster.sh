#!/bin/sh
# HELP: Restore PortMaster application
# ICON: sdcard
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_portmaster" "Restore PortMaster"
. /opt/muos/script/var/zip.sh


PM_DIR="/mnt/mmc/MUOS/PortMaster"
ALL_DONE() {
	ARC_UNSET

	if [ "$1" -eq 0 ]; then
		TASK_STATUS "Sync Filesystem"
		sync

		TASK_COMPLETE "PortMaster restored"
	else
		TASK_COMPLETE "PortMaster was not restored"
	fi

	exit "$1"
}

PM_ZIP="$MUOS_SHARE_DIR/archive/muos.portmaster.zip"

RT_DIR="$PM_DIR/runtimes"
RT_ZIP="$MUOS_SHARE_DIR/archive/runtimes.popular.aarch64.zip"

if [ ! -e "$PM_ZIP" ]; then
	TASK_ERROR "archive_missing" "The PortMaster archive could not be found."
	exit 1
fi

rm -rf "$PM_DIR"
mkdir -p "$PM_DIR"

SPACE_REQ="$(GET_ARCHIVE_BYTES "$PM_ZIP" "")"
! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$PM_DIR" && ALL_DONE 1

if ! EXTRACT_ARCHIVE "PortMaster" "$PM_ZIP" "/"; then
	TASK_ERROR "extract_failed" "PortMaster could not be extracted"
	ALL_DONE 1
fi

if [ -e "$RT_ZIP" ]; then
	SPACE_REQ="$(GET_ARCHIVE_BYTES "$RT_ZIP" "")"
	! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$RT_DIR" && ALL_DONE 1

	if ! EXTRACT_ARCHIVE "PortMaster Runtimes" "$RT_ZIP" "$RT_DIR"; then
		TASK_ERROR "extract_failed" "PortMaster Runtimes could not be extracted"
		ALL_DONE 1
	fi
fi

ALL_DONE 0
