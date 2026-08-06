#!/bin/sh
# HELP: Restore the default DraStic settings and hotkeys.
# ICON: retroarch
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_drastic_configuration" "Restore DraStic Configuration"


TASK_STATUS "Restoring DraStic Configuration"

DRASTIC_DIR="$MUOS_SHARE_DIR/emulator/drastic-trngaje"
rm -f "${DRASTIC_DIR}/config/drastic.cfg" "${DRASTIC_DIR}/resources/settings.json"

/opt/muos/script/control/drastic.sh

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Restore DraStic Configuration"

exit 0
