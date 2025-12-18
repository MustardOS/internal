#!/bin/sh
# HELP: Restore the default MustardOS themes and theme overrides
# ICON: sdcard

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

FRONTEND stop

SRC_DIR="$MUOS_SHARE_DIR/theme"
DST_DIR="$MUOS_STORE_DIR/theme"

cp -rfv "$SRC_DIR"/* "$DST_DIR/"

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

FRONTEND start task
exit 0
