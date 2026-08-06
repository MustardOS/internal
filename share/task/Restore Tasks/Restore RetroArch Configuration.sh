#!/bin/sh
# HELP: Restore the default RetroArch global settings and hotkeys (retroarch.cfg). Per-system core overrides will not be modified.
# ICON: retroarch
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_retroarch_configuration" "Restore RetroArch Configuration"


TASK_STATUS "Restoring RetroArch Configuration"

rm -f "$MUOS_SHARE_DIR/info/config/retroarch.cfg"
rm -f "$MUOS_SHARE_DIR/info/config/retroarch.autoload.cfg"
rm -f "$MUOS_SHARE_DIR/info/config/retroarch.cheevos.cfg"

/opt/muos/script/control/retroarch.sh
SET_VAR "config" "settings/advanced/retrofree" "0"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Restore RetroArch Configuration"

exit 0
