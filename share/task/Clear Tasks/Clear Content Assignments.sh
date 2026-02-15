#!/bin/sh
# HELP: Clear Core Assignments
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_CONTENT_DIR="$MUOS_SHARE_DIR/info/content"

echo "Removing all content assignments"
rm -rf "${MUOS_CONTENT_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

FRONTEND start task
exit 0
