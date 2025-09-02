#!/bin/sh
# HELP: Clear Core Assignments
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_CORE_DIR="/opt/muos/share/info/core"

echo "Removing all core assignments"
rm -rf "${MUOS_CORE_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
