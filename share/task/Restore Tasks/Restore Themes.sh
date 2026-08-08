#!/bin/sh
# HELP: Restore the default MustardOS themes and theme overrides
# ICON: sdcard
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_themes" "Restore Themes"
. /opt/muos/script/var/zip.sh


SRC_DIR="$MUOS_SHARE_DIR/theme"
DST_DIR="$MUOS_STORE_DIR/theme"

cp -rfv "$SRC_DIR"/* "$DST_DIR/"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Themes restored"

exit 0
