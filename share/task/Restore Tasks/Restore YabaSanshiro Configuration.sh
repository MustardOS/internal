#!/bin/sh
# HELP: Restore the default YabaSanshiro Controls.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Restoring YabaSanshiro Controls"

YABA_DIR="/opt/muos/share/emulator/yabasanshiro"
rm -f "${YABA_DIR}/.emulationstation/es_temporaryinput.cfg" "${YABA_DIR}/.yabasanshiro/keymapv2.json"

/opt/muos/script/control/yabasanshiro.sh

echo "Removing Per-game YabaSanshiro Configurations"

CONF_DIR="${YABA_DIR}/.yabasanshiro"
for CFG in "$CONF_DIR"/*.config; do
	[ "$(basename "$CFG")" != "28xx.config" ] && rm -f "$CFG"
done

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
