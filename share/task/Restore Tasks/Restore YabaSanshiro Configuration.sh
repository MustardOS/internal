#!/bin/sh
# HELP: Restores the default YabaSanshiro controls. Any YabaSanshiro controls you have changed will be replaced.
# ICON: retroarch
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/base.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_yabasanshiro_configuration" "Restore YabaSanshiro Configuration"

TASK_STATUS "Restoring YabaSanshiro Controls"

YABA_DIR="$MUOS_SHARE_DIR/emulator/yabasanshiro"
rm -f "${YABA_DIR}/.emulationstation/es_temporaryinput.cfg" "${YABA_DIR}/.yabasanshiro/keymapv2.json"

/opt/muos/script/control/yabasanshiro.sh

TASK_STATUS "Removing Per-game YabaSanshiro Configurations"

CONF_DIR="${YABA_DIR}/.yabasanshiro"
for CFG in "$CONF_DIR"/*.config; do
	[ "$(basename "$CFG")" != "28xx.config" ] && rm -f "$CFG"
done

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "YabaSanshiro configuration restored"
exit 0
