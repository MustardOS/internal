#!/bin/sh

# Backup script created for muOS 2405 Beans +
# This grabs all save files and save states and adds them to a .zip archive for easy restoration later using the muOS Task Commander.

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

SD_DEVICE="${DC_STO_SDCARD_DEV}p${DC_STO_SDCARD_NUM}"
USB_DEVICE="${DC_STO_USB_DEV}p${DC_STO_USB_NUM}"

pkill -STOP muxtask

if grep -m 1 "$USB_DEVICE" /proc/partitions >/dev/null; then
	echo "USB mounted, archiving to USB"
	DEST_DIR="$DC_STO_USB_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
elif grep -m 1 "$SD_DEVICE" /proc/partitions >/dev/null; then
	echo "SD2 mounted, archiving to SD2"
	DEST_DIR="$DC_STO_SDCARD_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
else
	echo "Archiving to SD1"
	DEST_DIR="$DC_STO_ROM_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
fi

# Determine RetroArch Save Directory
RA_SAVEFILE_DIR=$(grep 'savefile_dir' "$DC_STO_ROM_MOUNT/MUOS/retroarch/retroarch.cfg" | cut -d '"' -f 2)
RA_SAVESTATE_DIR=$(grep 'savestate_dir' "$DC_STO_ROM_MOUNT/MUOS/retroarch/retroarch.cfg" | cut -d '"' -f 2)

# Remove ~ from modified RA save paths
RA_SAVEFILE_DIR=$(echo "$RA_SAVEFILE_DIR" | sed 's/~//')
RA_SAVESTATE_DIR=$(echo "$RA_SAVESTATE_DIR" | sed 's/~//')

# Set RetroArch save source directories
if [ "$RA_SAVEFILE_DIR" = "$DC_STO_ROM_MOUNT/MUOS/save/file" ]; then
	MUOS_SAVEFILE_DIR="$RA_SAVEFILE_DIR"
fi

if [ "$RA_SAVESTATE_DIR" = "$DC_STO_ROM_MOUNT/MUOS/save/state" ]; then
	MUOS_SAVESTATE_DIR="$RA_SAVESTATE_DIR"
fi

# Define additional RA source directories
if [ -d "$DC_STO_ROM_MOUNT/.config" ]; then
	PPSSPP_RA_SAVE_DIR="$DC_STO_ROM_MOUNT/.config"
else
	PPSSPP_RA_SAVE_DIR=""
fi

# Define PPSSPP source directories
if [ -d "$DC_STO_ROM_MOUNT/MUOS/emulator/ppsspp" ]; then
	PPSSPP_SAVE_DIR="$DC_STO_ROM_MOUNT/MUOS/emulator/ppsspp/.config/ppsspp/PSP/SAVEDATA"
	PPSSPP_SAVESTATE_DIR="$DC_STO_ROM_MOUNT/MUOS/emulator/ppsspp/.config/ppsspp/PSP/PPSSPP_STATE"
else
	PPSSPP_SAVE_DIR=""
	PPSSPP_SAVESTATE_DIR=""
fi

# Define Dreamcast VMU source
if [ -d "$DC_STO_ROM_MOUNT/MUOS/bios/dc" ]; then
    if [ -f "$DC_STO_ROM_MOUNT/MUOS/bios/dc/dc_nvmem.bin" ]; then
        DC_NV="$DC_STO_ROM_MOUNT/MUOS/bios/dc/dc_nvmem.bin"
    fi
    DC_VMU_FILES=$(ls "$DC_STO_ROM_MOUNT/MUOS/bios/dc/vmu_save_"* 2>/dev/null)
    if [ -n "$DC_VMU_FILES" ]; then
        DC_VMU="$DC_STO_ROM_MOUNT/MUOS/bios/dc/vmu_save_"*
    fi
fi

# Define DraStic source directories
if [ -d "$DC_STO_ROM_MOUNT/MUOS/emulator/drastic" ]; then
	DRASTIC_SAVE_DIR="$DC_STO_ROM_MOUNT/MUOS/emulator/drastic/backup"
	DRASTIC_SAVESTATE_DIR="$DC_STO_ROM_MOUNT/MUOS/emulator/drastic/savestates"
else
	DRASTIC_SAVE_DIR=""
	DRASTIC_SAVESTATE_DIR=""
fi

# Define DraStic-steward source directories
if [ -d "$DC_STO_ROM_MOUNT/MUOS/emulator/drastic-steward" ]; then
	DRASTIC_STEWARD_SAVE_DIR="$DC_STO_ROM_MOUNT/MUOS/save/drastic/backup"
	DRASTIC_STEWARD_SAVESTATE_DIR="$DC_STO_ROM_MOUNT/MUOS/save/drastic/savestates"
else
	DRASTIC_STEWARD_SAVE_DIR=""
	DRASTIC_STEWARD_SAVESTATE_DIR=""
fi

DEST_FILE="$DEST_DIR/muOS-Save-$(date +"%Y-%m-%d_%H-%M").zip"

TO_BACKUP="
$MUOS_SAVEFILE_DIR
$MUOS_SAVESTATE_DIR
$PPSSPP_RA_SAVE_DIR
$PPSSPP_SAVE_DIR
$PPSSPP_SAVESTATE_DIR
$DRASTIC_SAVE_DIR
$DRASTIC_SAVESTATE_DIR
$DRASTIC_STEWARD_SAVE_DIR
$DRASTIC_STEWARD_SAVESTATE_DIR
$DC_NV
$DC_VMU
"
VALID_BACKUP=$(mktemp)

for BACKUP in $TO_BACKUP; do
	if [ -e "$BACKUP" ]; then
		echo "$BACKUP" >>"$VALID_BACKUP"
		echo "Found: $BACKUP"
	fi
done

if [ ! -s "$VALID_BACKUP" ]; then
	echo "No valid files found to backup!"
	sleep 1
	rm "$VALID_BACKUP"
else
	cd /
	echo "Archiving Saves"

	BACKUP_FILES=""
	while IFS= read -r FILE; do
		BACKUP_FILES="$BACKUP_FILES \"$FILE\""
	done <"$VALID_BACKUP"
	eval "zip -ru9 $DEST_FILE $BACKUP_FILES"

	rm "$VALID_BACKUP"
fi

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
