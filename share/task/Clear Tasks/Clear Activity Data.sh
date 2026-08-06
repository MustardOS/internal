#!/bin/sh
# HELP: Archive Activity Data
# ICON: clear
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "clear_activity_data" "Clear Activity Data"


MUOS_PLAY_DIR="$MUOS_STORE_DIR/info/track"
PLAY_FILE="$MUOS_PLAY_DIR/playtime_data.json"
ARCHIVE_DIR="$MUOS_PLAY_DIR/archive"

TASK_STATUS "Archiving Activity Data"

if [ -f "$PLAY_FILE" ]; then
	mkdir -p "$ARCHIVE_DIR"
	mv "$PLAY_FILE" "$ARCHIVE_DIR/playtime_data_$(date +%Y%m%d-%H%M%S).json"
fi

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Clear Activity Data"

exit 0
