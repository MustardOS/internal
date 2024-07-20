#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

pkill -STOP muxtask

MUOS_CONFIG_DIR="$DC_STO_ROM_MOUNT/MUOS/info/config"

echo "Removing all configurations"
rm -rf "${MUOS_CONFIG_DIR:?}"/*

echo "Restoring default RetroArch shader"
echo '#reference "../../retroarch/shaders/shimmerless/sharp-shimmerless.glslp"' >"$MUOS_CONFIG_DIR/global.glslp"

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
