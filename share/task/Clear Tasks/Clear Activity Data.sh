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
ARCHIVE_DIR="$MUOS_PLAY_DIR/archive/$(date +%Y%m%d-%H%M%S)"

TASK_STATUS "Archiving Activity Data"

for PLAY_FILE in "$MUOS_PLAY_DIR"/*.json "$MUOS_PLAY_DIR"/playtime_data.json.migrated; do
	[ -f "$PLAY_FILE" ] || continue
	mkdir -p "$ARCHIVE_DIR"
	mv "$PLAY_FILE" "$ARCHIVE_DIR/"
done

rm -f "$MUOS_PLAY_DIR/.current_session"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Activity data cleared"

exit 0
