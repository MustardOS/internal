#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask
/opt/muos/extra/muxlog &
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

MUOS_CONFIG_DIR="$DC_STO_ROM_MOUNT/MUOS/info/config"

echo "Removing all configurations" >/tmp/muxlog_info
rm -rf "${MUOS_CONFIG_DIR:?}"/*

echo "Adding default RetroArch shader" >/tmp/muxlog_info
echo '#reference "../../retroarch/shaders/shimmerless/sharp-shimmerless.glslp"' >"$MUOS_CONFIG_DIR/global.glslp"

echo "Sync Filesystem" >/tmp/muxlog_info
sync

echo "All Done!" >/tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

pkill -CONT muxtask
killall -q "Clear System Configuration.sh"
