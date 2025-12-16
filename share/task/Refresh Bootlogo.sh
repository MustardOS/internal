#!/bin/sh
# HELP: Refresh Bootlogo
# ICON: theme

. /opt/muos/script/var/func.sh

if ! UPDATE_BOOTLOGO_PNG; then
    UPDATE_BOOTLOGO
fi

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 5

exit 0
