#!/bin/sh
# HELP: Archive Activity Data
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_PLAY_DIR="$MUOS_STORE_DIR/info/track"
PLAY_FILE="$MUOS_PLAY_DIR/playtime_data.json"
ARCHIVE_DIR="$MUOS_PLAY_DIR/archive"

echo "Archiving Activity Data"

if [ -f "$PLAY_FILE" ]; then
	mkdir -p "$ARCHIVE_DIR"
	mv "$PLAY_FILE" "$ARCHIVE_DIR/playtime_data_$(date +%Y%m%d-%H%M%S).json"
fi

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

FRONTEND start task
exit 0
