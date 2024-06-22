#!/bin/sh

# Backup script created for muOS 2405 Beans +
# This should backup all core overrides, core assignments, favourites, and RA global config

# Grab device variables
. /opt/muos/script/system/parse.sh
DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

CONTROL_DIR="/opt/muos/device/$DEVICE/control"
ROM_MOUNT=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
SD_MOUNT=$(parse_ini "$DEVICE_CONFIG" "storage.sdcard" "mount")
USB_MOUNT=$(arse_ini "$DEVICE_CONFIG" "storage.usb" "mount")

SD_DEVICE=$(parse_ini "$DEVICE_CONFIG" "storage.sdcard" "dev")p$(parse_ini "$DEVICE_CONFIG" "storage.sdcard" "num")
USB_DEVICE=$(parse_ini "$DEVICE_CONFIG" "storage.usb" "dev")$(parse_ini "$DEVICE_CONFIG" "storage.usb" "num")

# Suspend the muxtask program
pkill -STOP muxtask

# Fire up the logger!
/opt/muos/extra/muxlog &
sleep 1

echo "Waiting..." > /tmp/muxlog_info
sleep 1

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

# Grab current date
DATE=$(date +%Y-%m-%d)

# Core Overrides
RA_OVERRIDES="$ROM_MOUNT/MUOS/info/config"

# Global Configs
RA64_CONFIG="$ROM_MOUNT/MUOS/retroarch/retroarch.cfg"
RA32_CONFIG="$ROM_MOUNT/MUOS/retroarch/retroarch32.cfg"

# Core Assignments
MU_ASSIGN="$ROM_MOUNT/MUOS/info/core"

# Favourites
MU_FAVES="$ROM_MOUNT/MUOS/info/favourite"

# Set destination file based on priority
# USB -> SD2 -> SD1
if grep -m 1 "$USB_DEVICE" /proc/partitions > /dev/null; then
    echo "USB mounted, archiving to USB" > /tmp/muxlog_info
    mkdir -p "$USB_MOUNT/BACKUP/"
    DEST_DIR="$USB_MOUNT/BACKUP"
elif grep -m 1 "$SD_DEVICE" /proc/partitions > /dev/null; then
    echo "SD2 mounted, archiving to SD2" > /tmp/muxlog_info
    mkdir -p "$SD_MOUNT/BACKUP/"
    DEST_DIR="$SD_MOUNT/BACKUP"
else
    echo "Archiving to SD1" > /tmp/muxlog_info
    DEST_DIR="$ROM_MOUNT/BACKUP"
fi

# Set Destination File
DEST_FILE="$DEST_DIR/Config-$DATE.zip"

# Change to root so we capture full path in .zip
cd /

# Create the backup
echo "Archiving Config" > /tmp/muxlog_info
zip -ru9 "$DEST_FILE" "$RA_OVERRIDES" "$RA64_CONFIG" "$RA32_CONFIG" "$MU_ASSIGN" "$MU_FAVES" > "$TMP_FILE" 2>&1 &

# Tail zip process and push to muxlog
C_LINE=""
while true; do
	IS_WORKING=$(ps aux | grep '[z]ip' | awk '{print $1}')

	if [ -s "$TMP_FILE" ]; then
		N_LINE=$(tail -n 1 "$TMP_FILE" | sed 's/^[[:space:]]*//')
		if [ "$N_LINE" != "$C_LINE" ]; then
			echo "$N_LINE"
			echo "$N_LINE" > /tmp/muxlog_info
			C_LINE="$N_LINE"
		fi
	fi

	if [ -z "$IS_WORKING" ]; then
		break
	fi
	
	sleep 0.25
done

# Sync filesystem just-in-case :)
echo "Sync Filesystem" > /tmp/muxlog_info
sync

echo "All Done!" > /tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

# Resume the muxtask program
pkill -CONT muxtask
killall -q "Backup Config.sh"
