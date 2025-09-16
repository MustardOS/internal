#!/bin/sh
# HELP: Clear Network Profiles
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_NP_DIR="$MUOS_STORE_DIR/network"

echo "Deleting Network Profiles"
rm -rf "${MUOS_NP_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
