#!/bin/sh
# HELP: Restore the default PPSSPP-SA settings and hotkeys.
# ICON: retroarch
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_ppsspp_configuration" "Restore PPSSPP Configuration"


TASK_STATUS "Restoring PPSSPP Configuration"

PPSSPP_SYS="$MUOS_SHARE_DIR/emulator/ppsspp/.config/ppsspp/PSP/SYSTEM"
rm -f "${PPSSPP_SYS}/controls.ini" "${PPSSPP_SYS}/ppsspp.ini"

/opt/muos/script/control/ppsspp.sh

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Restore PPSSPP Configuration"

exit 0
