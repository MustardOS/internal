#!/bin/sh
# HELP: Clear Core Assignments
# ICON: clear

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

MUOS_CORE_DIR="/run/muos/storage/info/core"

echo "Removing all core assignments"
rm -rf "${MUOS_CORE_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
