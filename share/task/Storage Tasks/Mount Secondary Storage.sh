#!/bin/sh
# HELP: Will attempt to mount any secondary storage that has been configured by the system
# ICON: storage

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Trying to mount Secondary Storage"
/opt/muos/script/mount/storage.sh "sdcard" "mount"

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
