#!/bin/sh
# HELP: Clear Collections
# ICON: clear
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "clear_collections" "Clear Collections"


MUOS_COLL_DIR="$MUOS_STORE_DIR/info/collection"

TASK_STATUS "Deleting Collection Files"
rm -rf "${MUOS_COLL_DIR:?}"/*

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Clear Collections"

exit 0
