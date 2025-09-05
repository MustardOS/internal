#!/bin/sh
# HELP: Restore the default DraStic settings and hotkeys.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Restoring DraStic Configuration"

DRASTIC_DIR="/opt/muos/share/emulator/drastic-trngaje"
rm -f "${DRASTIC_DIR}/config/drastic.cfg" "${DRASTIC_DIR}/resources/settings.json"

/opt/muos/script/control/drastic.sh

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
