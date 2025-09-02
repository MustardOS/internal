#!/bin/sh
# HELP: Will attempt to mount any USB external storage that has been configured by the system
# ICON: storage

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Trying to mount USB External Storage"
/opt/muos/script/mount/usb.sh mount

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
