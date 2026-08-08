#!/bin/sh
# HELP: Restore the default MustardOS background music
# ICON: sdcard
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_background_music" "Restore Background Music"


SRC_DIR="$MUOS_SHARE_DIR/media/music"
DST_DIR="$MUOS_STORE_DIR/music"

cp -rfv "$SRC_DIR"/* "$DST_DIR/"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Background music restored"

exit 0
