#!/bin/sh

# Backup script created for muOS 2405 Beans +
# This should backup all core overrides, core assignments, favourites, and RA global config

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

SD_DEVICE="${DC_STO_SDCARD_DEV}p${DC_STO_SDCARD_NUM}"
USB_DEVICE="${DC_STO_USB_DEV}p${DC_STO_USB_NUM}"

pkill -STOP muxtask
/opt/muos/extra/muxlog &
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

if grep -m 1 "$USB_DEVICE" /proc/partitions >/dev/null; then
	echo "USB mounted, archiving to USB" >/tmp/muxlog_info
	mkdir -p "$DC_STO_USB_MOUNT/BACKUP/"
	DEST_DIR="$DC_STO_USB_MOUNT/BACKUP"
elif grep -m 1 "$SD_DEVICE" /proc/partitions >/dev/null; then
	echo "SD2 mounted, archiving to SD2" >/tmp/muxlog_info
	mkdir -p "$DC_STO_SDCARD_MOUNT/BACKUP/"
	DEST_DIR="$DC_STO_SDCARD_MOUNT/BACKUP"
else
	echo "Archiving to SD1" >/tmp/muxlog_info
	DEST_DIR="$DC_STO_ROM_MOUNT/BACKUP"
fi

DEST_FILE="$DEST_DIR/Config-$(date +%Y-%m-%d).zip"
RA_OVERRIDES="$ROM_MOUNT/MUOS/info/config"
RA_CONFIG="$ROM_MOUNT/MUOS/retroarch/retroarch.cfg"
MU_ASSIGN="$ROM_MOUNT/MUOS/info/core"
MU_FAVES="$ROM_MOUNT/MUOS/info/favourite"
MU_HISTORY="$ROM_MOUNT/MUOS/info/history"

cd /
echo "Archiving Config" >/tmp/muxlog_info
zip -ru9 "$DEST_FILE" "$RA_OVERRIDES" "$RA_CONFIG" "$MU_ASSIGN" "$MU_FAVES" "$MU_HISTORY" >"$TMP_FILE" 2>&1 &

# Tail zip process and push to muxlog
C_LINE=""
while true; do
	IS_WORKING=$(ps aux | grep '[z]ip' | awk '{print $1}')

	if [ -s "$TMP_FILE" ]; then
		N_LINE=$(tail -n 1 "$TMP_FILE" | sed 's/^[[:space:]]*//')
		if [ "$N_LINE" != "$C_LINE" ]; then
			echo "$N_LINE"
			echo "$N_LINE" >/tmp/muxlog_info
			C_LINE="$N_LINE"
		fi
	fi

	if [ -z "$IS_WORKING" ]; then
		break
	fi

	sleep 0.25
done

echo "Sync Filesystem" >/tmp/muxlog_info
sync

echo "All Done!" >/tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

pkill -CONT muxtask
killall -q "Backup Config.sh"
