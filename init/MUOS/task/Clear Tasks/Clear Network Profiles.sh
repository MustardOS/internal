#!/bin/sh
# HELP: Clear Network Profiles
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

MUOS_NP_DIR="/run/muos/storage/network"

echo "Deleting Network Profiles"
rm -rf "${MUOS_NP_DIR:?}"/*

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

FRONTEND start task
exit 0
