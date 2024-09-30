#!/bin/sh
# HELP: Restore RetroArch Configuration
# ICON: retroarch

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

echo "Restoring RetroArch Configuration"
rm -f /run/muos/storage/info/config/retroarch.cfg
/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
