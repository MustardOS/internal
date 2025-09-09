#!/bin/sh
# HELP: Restore PortMaster application
# ICON: sdcard

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

FRONTEND stop

PM_DIR="/mnt/mmc/MUOS/PortMaster"
PM_ZIP="$MUOS_SHARE_DIR/archive/muos.portmaster.zip"

if [ ! -e "$PM_ZIP" ]; then
	printf "\nError: PortMaster archive not found!\n"
	TBOX sleep 2

	FRONTEND start task
	exit 1
fi

rm -rf "$PM_DIR"
mkdir -p "$PM_DIR"

SPACE_REQ="$(GET_ARCHIVE_BYTES "$PM_ZIP" "")"
! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$PM_DIR" && ALL_DONE 1

if ! EXTRACT_ARCHIVE "PortMaster" "$PM_ZIP" "/"; then
	printf "\nExtraction Failed...\n"
	ALL_DONE 1
fi

printf "\nSync Filesystem"
sync

printf "\nAll Done!"
TBOX sleep 2

FRONTEND start task
exit 0
