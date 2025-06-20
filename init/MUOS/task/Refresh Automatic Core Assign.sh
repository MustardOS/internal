#!/bin/sh
# HELP: Refresh Automatic Core Assign
# ICON: junk

. /opt/muos/script/var/func.sh

FRONTEND stop

/opt/muos/script/system/assign.sh -p -v

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 5

FRONTEND start task
exit 0
