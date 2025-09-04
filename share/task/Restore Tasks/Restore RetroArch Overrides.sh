#!/bin/sh
# HELP: Restore the default RetroArch overrides (core options, overlays, remaps, shaders, etc.). Global settings (retroarch.cfg) will not be modified.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Restoring RetroArch Overrides"

rsync --archive --checksum --delete --exclude /retroarch.cfg /opt/muos/default/info/config/ /opt/muos/share/info/config/

/opt/muos/script/control/retroarch.sh

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
