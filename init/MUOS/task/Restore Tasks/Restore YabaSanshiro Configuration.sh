#!/bin/sh
# HELP: Restore the default YabaSanshiro Controls.
# ICON: retroarch

. /opt/muos/script/var/func.sh

FRONTEND stop

MOUNT="$(GET_VAR "device" "storage/rom/mount")"

# Restore control config
echo "Restoring YabaSanshiro Controls"
rm -f "$MOUNT/MUOS/emulator/yabasanshiro/.emulationstation/es_temporaryinput.cfg" \
	"$MOUNT/MUOS/emulator/yabasanshiro/.yabasanshiro/keymapv2.json"
/opt/muos/device/script/control.sh

# Remove any per-game configs
CONF_DIR="$MOUNT/MUOS/emulator/yabasanshiro/.yabasanshiro"
echo "Removing Per-game YabaSanshiro Configurations"
for file in "$CONF_DIR"/*.config; do
    if [ "$(basename "$file")" != "28xx.config" ]; then
        rm -f "$file"
    fi
done

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

FRONTEND start task
exit 0
