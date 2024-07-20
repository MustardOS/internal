#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask

echo "Restoring RetroArch Configuration"
rm -rf "$DC_STO_ROM_MOUNT/MUOS/retroarch/retroarch.cfg"
/opt/muos/device/"$DEVICE_TYPE"/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
