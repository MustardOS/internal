#!/bin/sh
# HELP: Clear SFTPGO Keys
# ICON: clear
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

# This script will remove the SFTPGO keys
# These will be (re)generated on next boot.

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "clear_sftpgo_keys" "Clear SFTPGO Keys"


SFTP_DIR="/opt/sftpgo"

TASK_STATUS "Deleting SFTPGO Keys"
rm -f "${SFTP_DIR:?}"/id_*

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Clear SFTPGO Keys"
TASK_STATUS "Please reboot your device."
sleep 5

exit 0
