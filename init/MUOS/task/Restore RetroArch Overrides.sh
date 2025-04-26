#!/bin/sh
# HELP: Restore the default RetroArch overrides (core options, overlays, remaps, shaders, etc.). Global settings (retroarch.cfg) will not be modified.
# ICON: retroarch

. /opt/muos/script/var/func.sh

pkill -STOP muxfrontend

echo "Restoring RetroArch Overrides"
rsync --archive --checksum --delete --exclude /retroarch.cfg /opt/muos/default/MUOS/info/config/ /run/muos/storage/info/config/

# control.sh recreates device-specific RetroArch core overrides and remaps.
/opt/muos/device/current/script/control.sh

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

pkill -CONT muxfrontend
exit 0
