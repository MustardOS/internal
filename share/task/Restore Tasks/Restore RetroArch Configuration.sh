#!/bin/sh
# HELP: Restore the default RetroArch global settings and hotkeys (retroarch.cfg). Per-system core overrides will not be modified.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Restoring RetroArch Configuration"

rm -f "$MUOS_SHARE_DIR/info/config/retroarch.cfg"
rm -f "$MUOS_SHARE_DIR/info/config/retroarch.autoload.cfg"
rm -f "$MUOS_SHARE_DIR/info/config/retroarch.cheevos.cfg"

/opt/muos/script/control/retroarch.sh
SET_VAR "config" "settings/advanced/retrofree" "0"

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
