#!/bin/sh
# HELP: Refresh Bootlogo
# ICON: theme

. /opt/muos/script/var/func.sh

UPDATE_BOOTLOGO

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 5

exit 0
