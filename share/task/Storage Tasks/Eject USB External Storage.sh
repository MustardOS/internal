#!/bin/sh
# HELP: Will attempt to eject any external USB storage that has been configured by the system
# ICON: storage

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Trying to eject USB External Storage"
/opt/muos/script/mount/usb.sh "usb" "eject"

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
