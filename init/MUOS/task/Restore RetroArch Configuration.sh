#!/bin/sh

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

echo "Restoring RetroArch Configuration"
rm -rf "$(GET_VAR "device" "storage/rom/mount")/MUOS/retroarch/retroarch.cfg"
/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
