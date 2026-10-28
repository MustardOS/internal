#!/bin/sh
# HELP: Rebuilds the boot logo from the active theme and writes it to the boot partition, so the next startup shows it. Use this if the boot logo did not change after switching themes.
# ICON: theme
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/theme.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "refresh_bootlogo" "Refresh Bootlogo"

TASK_STATUS "Rebuilding Boot Logo"
UPDATE_BOOTLOGO

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Boot logo refreshed"

exit 0
