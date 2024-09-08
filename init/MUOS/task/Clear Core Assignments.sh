#!/bin/sh
# HELP: Clear Core Assignments
# ICON: core

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/global/storage.sh

pkill -STOP muxtask

MUOS_CORE_DIR="$GC_STO_CONFIG/MUOS/info/core"

echo "Removing all core assignments"
rm -rf "${MUOS_CORE_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
