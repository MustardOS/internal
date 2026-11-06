#!/bin/sh
# HELP: Restores the default OpenBOR settings. Any OpenBOR settings you have changed will be replaced.
# ICON: retroarch
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/base.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_openbor_configuration" "Restore OpenBOR Configuration"

TASK_STATUS "Restoring OpenBOR Configuration"

/opt/muos/script/control/openbor.sh FORCE_COPY

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "OpenBOR configuration restored"

exit 0
