#!/bin/sh
# HELP: Restore the default PPSSPP-SA settings and hotkeys.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Restoring PPSSPP Configuration"

PPSSPP_SYS="$MUOS_SHARE_DIR/emulator/ppsspp/.config/ppsspp/PSP/SYSTEM"
rm -f "${PPSSPP_SYS}/controls.ini" "${PPSSPP_SYS}/ppsspp.ini"

/opt/muos/script/control/ppsspp.sh

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
