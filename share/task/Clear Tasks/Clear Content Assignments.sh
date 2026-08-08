#!/bin/sh
# HELP: Clear Core Assignments
# ICON: clear
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "clear_content_assignments" "Clear Content Assignments"


MUOS_CONTENT_DIR="$MUOS_SHARE_DIR/info/content"

TASK_STATUS "Removing all content assignments"
rm -rf "${MUOS_CONTENT_DIR:?}"/*

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Content assignments cleared"

exit 0
