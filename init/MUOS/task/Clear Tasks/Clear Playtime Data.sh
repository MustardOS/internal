#!/bin/sh
# HELP: Clear Playtime Data
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_PLAY_DIR="/run/muos/storage/info/track"

echo "Deleting Playtime Data"
rm -f "$MUOS_PLAY_DIR/playtime_data.json"

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
