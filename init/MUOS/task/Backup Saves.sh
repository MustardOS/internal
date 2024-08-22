#!/bin/sh

# Backup script created for muOS 2405 Beans +
# This grabs all save files and save states and adds them to a .zip archive for easy restoration later using the muOS Task Commander.

. /opt/muos/script/var/func.sh

SD_DEVICE="$(GET_VAR "device" "storage/sdcard/dev")$(GET_VAR "device" "storage/sdcard/sep")$(GET_VAR "device" "storage/sdcard/num")"
USB_DEVICE="$(GET_VAR "device" "storage/usb/dev")$(GET_VAR "device" "storage/usb/sep")$(GET_VAR "device" "storage/usb/num")"

pkill -STOP muxtask

if grep -m 1 "$USB_DEVICE" /proc/partitions >/dev/null; then
	echo "USB mounted, archiving to USB"
	DEST_DIR="$(GET_VAR "device" "storage/usb/mount")/BACKUP"
	mkdir -p "$DEST_DIR"
elif grep -m 1 "$SD_DEVICE" /proc/partitions >/dev/null; then
	echo "SD2 mounted, archiving to SD2"
	DEST_DIR="$(GET_VAR "device" "storage/sdcard/mount")/BACKUP"
	mkdir -p "$DEST_DIR"
else
	echo "Archiving to SD1"
	DEST_DIR="$(GET_VAR "device" "storage/rom/mount")/BACKUP"
	mkdir -p "$DEST_DIR"
fi

# Determine RetroArch Save Directory
RA_SAVEFILE_DIR=$(grep 'savefile_dir' "$(GET_VAR "device" "storage/rom/mount")/MUOS/retroarch/retroarch.cfg" | cut -d '"' -f 2)
RA_SAVESTATE_DIR=$(grep 'savestate_dir' "$(GET_VAR "device" "storage/rom/mount")/MUOS/retroarch/retroarch.cfg" | cut -d '"' -f 2)

# Remove ~ from modified RA save paths
RA_SAVEFILE_DIR=$(echo "$RA_SAVEFILE_DIR" | sed 's/~//')
RA_SAVESTATE_DIR=$(echo "$RA_SAVESTATE_DIR" | sed 's/~//')

# Set RetroArch save source directories
if [ "$RA_SAVEFILE_DIR" = "/run/muos/storage/save/file" ]; then
	MUOS_SAVEFILE_DIR="$RA_SAVEFILE_DIR"
fi

if [ "$RA_SAVESTATE_DIR" = "/run/muos/storage/save/state" ]; then
	MUOS_SAVESTATE_DIR="$RA_SAVESTATE_DIR"
fi

# Define additional RA source directories
if [ -d "$(GET_VAR "device" "storage/rom/mount")/.config" ]; then
	PPSSPP_RA_SAVE_DIR="$(GET_VAR "device" "storage/rom/mount")/.config"
else
	PPSSPP_RA_SAVE_DIR=""
fi

# Define PPSSPP source directories
if [ -d "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp" ]; then
	PPSSPP_SAVE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp/.config/ppsspp/PSP/SAVEDATA"
	PPSSPP_SAVESTATE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp/.config/ppsspp/PSP/PPSSPP_STATE"
else
	PPSSPP_SAVE_DIR=""
	PPSSPP_SAVESTATE_DIR=""
fi

# Define Dreamcast VMU source
if [ -d "/run/muos/storage/bios/dc" ]; then
	if [ -f "/run/muos/storage/bios/dc/dc_nvmem.bin" ]; then
		DREAMCAST_NVMEM="/run/muos/storage/bios/dc/dc_nvmem.bin"
	fi
	VMU_SAVES=$(ls "/run/muos/storage/bios/dc/vmu_save_"* 2>/dev/null)
	if [ -n "$VMU_SAVES" ]; then
		DREAMCAST_VMU="/run/muos/storage/bios/dc/vmu_save_"*
	fi
fi

# Define DraStic source directories
if [ -d "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic" ]; then
	DRASTIC_SAVE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic/backup"
	DRASTIC_SAVESTATE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic/savestates"
else
	DRASTIC_SAVE_DIR=""
	DRASTIC_SAVESTATE_DIR=""
fi

# Define DraStic-steward source directories
if [ -d "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic-steward" ]; then
	DRASTIC_STEWARD_SAVE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/save/drastic/backup"
	DRASTIC_STEWARD_SAVESTATE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/save/drastic/savestates"
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
$DREAMCAST_NVMEM
$DREAMCAST_VMU
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
