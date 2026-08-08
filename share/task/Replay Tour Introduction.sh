#!/bin/sh
# HELP: Show the introduction on every menu again, as it appeared the first time you used the device.
# ICON: star
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# NEVER_CANCEL: 1
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "replay_orientation" "Replay Orientation"

TASK_STATUS "Enabling Orientation"

SET_VAR "config" "settings/general/orientation" 1
rm -rf "$MUOS_CONF_GLOBAL/orientation"

TASK_DETAIL "Every menu will introduce itself once more"

sync

TASK_COMPLETE "Tour introduction will show again"
