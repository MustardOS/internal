#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask
/opt/muos/extra/muxlog &
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

MUOS_NEW_PM_DIR="/opt/muos/archive/portmaster"
MUOS_PM_DIR="$DC_STO_ROM_MOUNT/MUOS/PortMaster"

echo "Deleting existing PortMaster install" >/tmp/muxlog_info
rm -rf "${MUOS_PM_DIR:?}"/*

echo "Reinstalling PortMaster from base" >/tmp/muxlog_info
cp -r "$MUOS_NEW_PM_DIR"/* "$MUOS_PM_DIR"/.

echo "Sync Filesystem" >/tmp/muxlog_info
sync

echo "All Done!" >/tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

pkill -CONT muxtask
killall -q "Restore PortMaster.sh"
