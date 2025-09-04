#!/bin/sh
# HELP: Restore the default RetroArch global settings and hotkeys (retroarch.cfg). Per-system core overrides will not be modified.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Restoring RetroArch Configuration"

rm -f /opt/muos/share/info/config/retroarch.cfg

/opt/muos/script/control/retroarch.sh

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
