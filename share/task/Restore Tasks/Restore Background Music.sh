#!/bin/sh
# HELP: Restore the default MustardOS background music
# ICON: sdcard

. /opt/muos/script/var/func.sh

FRONTEND stop

SRC_DIR="$MUOS_SHARE_DIR/media/music"
DST_DIR="$MUOS_STORE_DIR/music"

cp -rfv "$SRC_DIR"/* "$DST_DIR/"

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
