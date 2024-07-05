#!/bin/sh

# Backup script created for muOS 2405 Beans +
# This grabs all save files and save states and adds them to a .zip archive for easy restoration later using the muOS Task Commander.

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
	DEST_DIR="$DC_STO_USB_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
elif grep -m 1 "$SD_DEVICE" /proc/partitions >/dev/null; then
	echo "SD2 mounted, archiving to SD2" >/tmp/muxlog_info
	DEST_DIR="$DC_STO_SDCARD_MOUNT/BACKUP"
	mkdir -p "$DEST_DIR"
else
	echo "Archiving to SD1" >/tmp/muxlog_info
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
"
VALID_BACKUP=$(mktemp)

for BACKUP in $TO_BACKUP; do
	if [ -e "$BACKUP" ]; then
		echo "$BACKUP" >>"$VALID_BACKUP"
		echo "Found: $BACKUP" >/tmp/muxlog_info
	fi
done

if [ ! -s "$VALID_BACKUP" ]; then
	echo "No valid files found to backup!" >/tmp/muxlog_info
	sleep 1
	rm "$VALID_BACKUP"
else
	cd /
	echo "Archiving Saves" >/tmp/muxlog_info
	zip -ru9 "$DEST_FILE" "$(cat "$VALID_BACKUP")" >"$TMP_FILE" 2>&1 &

	C_LINE=""
	while true; do
		IS_WORKING=$(pgrep -f "zip")

		if [ -s "$TMP_FILE" ]; then
			N_LINE=$(tail -n 1 "$TMP_FILE" | sed 's/^[[:space:]]*//')
			if [ "$N_LINE" != "$C_LINE" ]; then
				# Don't want to scare people unnecessarily!
				if ! echo "$N_LINE" | grep -q "^zip warning:"; then
					echo "$N_LINE"
					echo "$N_LINE" >/tmp/muxlog_info
				fi
				C_LINE="$N_LINE"
			fi
		fi

		if [ -z "$IS_WORKING" ]; then
			break
		fi

		sleep 0.1
	done

	rm "$VALID_BACKUP"

	echo "Sync Filesystem" >/tmp/muxlog_info
	sync

	echo "All Done!" >/tmp/muxlog_info
	sleep 1
fi

pkill -CONT muxtask

while true; do
	if ! toybox ps -Al | grep '[m]uxtask' | grep 'T' >/dev/null; then
		echo "Waiting to quit..." >/tmp/muxlog_info
		break
	fi
	sleep 0.1
	pkill -CONT muxtask
done

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

killall -q "$(basename "$0")"
