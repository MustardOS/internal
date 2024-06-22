#!/bin/sh

# Backup script created for muOS 2405 Beans +
# This grabs all save files and save states and adds them to a .zip archive for easy restoration later using the muOS Task Commander.

# Grab device variables
. /opt/muos/script/system/parse.sh
DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

CONTROL_DIR="/opt/muos/device/$DEVICE/control"
ROM_MOUNT=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
SD_MOUNT=$(parse_ini "$DEVICE_CONFIG" "storage.sdcard" "mount")
USB_MOUNT=$(parse_ini "$DEVICE_CONFIG" "storage.usb" "mount")

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

# Grab current date and time
DATETIME=$(date +"%Y-%m-%dT%H%M%S")

# Determine RetroArch Save Directory
RA_SAVEFILE_DIR=$(grep 'savefile_dir' "$ROM_MOUNT/MUOS/retroarch/retroarch.cfg" | cut -d '"' -f 2)
RA_SAVESTATE_DIR=$(grep 'savestate_dir' "$ROM_MOUNT/MUOS/retroarch/retroarch.cfg" | cut -d '"' -f 2)

# Remove ~ from modified RA save paths
RA_SAVEFILE_DIR=$(echo "$RA_SAVEFILE_DIR" | sed 's/~//')
RA_SAVESTATE_DIR=$(echo "$RA_SAVESTATE_DIR" | sed 's/~//')

# Set RetroArch save source directories
if [ "$RA_SAVEFILE_DIR" = "$ROM_MOUNT/MUOS/save/file" ]; then
    MUOS_SAVEFILE_DIR="$RA_SAVEFILE_DIR"
fi

if [ "$RA_SAVESTATE_DIR" = "$ROM_MOUNT/MUOS/save/state" ]; then
    MUOS_SAVESTATE_DIR="$RA_SAVESTATE_DIR"
fi

# Define additional RA source directories
if [ -d "$ROM_MOUNT/.config" ]; then
    PPSSPP_RA_SAVE_DIR="$ROM_MOUNT/.config"
else
    PPSSPP_RA_SAVE_DIR=""
fi

# Define PPSSPP source directories
if [ -d "$ROM_MOUNT/MUOS/emulator/ppsspp" ]; then
    PPSSPP_SAVE_DIR="$ROM_MOUNT/MUOS/emulator/ppsspp/.config/ppsspp/PSP/SAVEDATA"
    PPSSPP_SAVESTATE_DIR="$ROM_MOUNT/MUOS/emulator/ppsspp/.config/ppsspp/PSP/PPSSPP_STATE"
else
    PPSSPP_SAVE_DIR=""
    PPSSPP_SAVESTATE_DIR=""
fi

# Define DraStic source directories
if [ -d "$ROM_MOUNT/MUOS/emulator/drastic" ]; then
    Drastic_SAVE_DIR="$ROM_MOUNT/MUOS/emulator/drastic/backup"
    Drastic_SAVESTATE_DIR="$ROM_MOUNT/MUOS/emulator/drastic/savestates"
else
    Drastic_SAVE_DIR=""
    Drastic_SAVESTATE_DIR=""
fi

# Define DraStic-steward source directories
if [ -d "$ROM_MOUNT/MUOS/emulator/drastic-steward" ]; then
    Drasticsteward_SAVE_DIR="$ROM_MOUNT/MUOS/save/drastic/backup"
    Drasticsteward_SAVESTATE_DIR="$ROM_MOUNT/MUOS/save/drastic/savestates"
else
    Drasticsteward_SAVE_DIR=""
    Drasticsteward_SAVESTATE_DIR=""
fi

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

DEST_FILE="$DEST_DIR/muOS-Save-$DATETIME.zip"

# Change to root so we capture full path in .zip
cd /

# Create the backup
echo "Archiving Saves" > /tmp/muxlog_info
zip -ru9 "$DEST_FILE" "$MUOS_SAVEFILE_DIR" "$MUOS_SAVESTATE_DIR" "$PPSSPP_RA_SAVE_DIR" "$PPSSPP_SAVE_DIR" "$PPSSPP_SAVESTATE_DIR" "$Drastic_SAVE_DIR" "$Drastic_SAVESTATE_DIR" "$Drasticsteward_SAVE_DIR" "$Drasticsteward_SAVESTATE_DIR" > "$TMP_FILE" 2>&1 &

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
killall -q "Backup Saves.sh"
