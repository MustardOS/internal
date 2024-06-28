#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask
/opt/muos/extra/muxlog &
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

echo "Restoring RetroArch Configuration" >/tmp/muxlog_info
rm -rf "$DC_STO_ROM_MOUNT/MUOS/retroarch/retroarch.cfg"
/opt/muos/device/"$DEVICE_TYPE"/script/control.sh

echo "Sync Filesystem" >/tmp/muxlog_info
sync

echo "All Done!" >/tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

pkill -CONT muxtask
killall -q "Restore RetroArch Configuration.sh"
