#!/bin/sh
# HELP: Restore the default RetroArch overrides (core options, overlays, remaps, shaders, etc.). Global settings (retroarch.cfg) will not be modified.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Restoring RetroArch Overrides"
rsync --archive --checksum --delete --exclude /retroarch.cfg /opt/muos/default/MUOS/info/config/ /run/muos/storage/info/config/

# control.sh recreates device-specific RetroArch core overrides and remaps.
/opt/muos/device/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
