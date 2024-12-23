#!/bin/sh
# HELP: Migrate to SD2
# ICON: sdcard

#---------------------------------------------------------#
# This script is designed to migrate all user data stored
# on SD1 to SD2
# *-- NO DATA IS REMOVED FROM SD1! --*
# All locations modifiable via Storage Prefs are moved.
# Once the migration is complete set the pref to AUTO
#---------------------------------------------------------#

# Check if using e Pre-Banana version of muOS
MUOS_VER=$(head -n 1 /opt/muos/config/version.txt | awk '{print $1}')
if [ $(echo "$MUOS_VER < 2405.3" | bc) -eq 1 ]; then
	CURRENT_VER="PREBANANA"
else
	CURRENT_VER="BANANA"
fi

# Fire up the logger (Pre-Banana)
if [ $CURRENT_VER = "PREBANANA" ]; then
	/opt/muos/extra/muxlog &
	sleep 1

	TMP_FILE=/tmp/muxlog_global
	rm -rf "$TMP_FILE"
fi

# Define all moveable storage locations.
SD1_BIOS="/mnt/mmc/MUOS/bios"
SD1_CATALOGUE="/mnt/mmc/MUOS/info/catalogue"
SD1_CONFIG="/mnt/mmc/MUOS/info/config"
SD1_CONTENT="/mnt/mmc/MUOS/info/core /mnt/mmc/MUOS/info/favourite /mnt/mmc/MUOS/info/history"
SD1_LANGUAGE="/mnt/mmc/MUOS/language"
SD1_MUSIC="/mnt/mmc/MUOS/music"
SD1_NAME="/mnt/mmc/MUOS/info/name"
SD1_NETWORK="/mnt/mmc/MUOS/network"
SD1_SAVE="/mnt/mmc/MUOS/save"
SD1_SCREENSHOT="/mnt/mmc/MUOS/screenshot"
SD1_THEME="/mnt/mmc/MUOS/theme"
SD1_OPENBOR_SAVE="/mnt/mmc/MUOS/emulator/openbor/userdata/saves/openbor/"
SD1_OPENBOR_SCREENSHOT="/mnt/mmc/MUOS/emulator/openbor/userdata/screenshots/openbor/"
SD1_PICO8="/mnt/mmc/MUOS/pico8/.lexaloffle/pico-8/"
SD1_PICO8_BIOS="/mnt/mmc/MUOS/emulator/pico8/pico8_64 /mnt/mmc/MUOS/emulator/pico8/pico8.dat"
SD1_PPSSPP_SAVE="/mnt/mmc/MUOS/emulator/ppsspp/.config/ppsspp/PSP/SAVEDATA/"
SD1_PPSSPP_STATE="/mnt/mmc/MUOS/emulator/ppsspp/.config/ppsspp/PSP/PPSSPP_STATE/"
if [ $CURRENT_VER = "PREBANANA" ]; then
	SD1_DRASTIC_SAVE="/mnt/mmc/MUOS/emulator/drastic-steward/backup/"
else
	SD1_DRASTIC_SAVE="/mnt/mmc/MUOS/emulator/drastic/backup/"
fi

# Define all target locations
SD2_BIOS="/mnt/sdcard/MUOS"
SD2_CATALOGUE="/mnt/sdcard/MUOS/info"
SD2_CONFIG="/mnt/sdcard/MUOS/info"
SD2_CONTENT="/mnt/sdcard/MUOS/info"
SD2_LANGUAGE="/mnt/sdcard/MUOS"
SD2_MUSIC="/mnt/sdcard/MUOS"
SD2_NAME="/mnt/sdcard/MUOS/info"
SD2_NETWORK="/mnt/sdcard/MUOS"
SD2_SAVE="/mnt/sdcard/MUOS"
SD2_SCREENSHOT="/mnt/sdcard/MUOS"
SD2_THEME="/mnt/sdcard/MUOS"
SD2_OPENBOR_SAVE="/mnt/sdcard/MUOS/save/file/OpenBOR-Ext"
SD2_OPENBOR_SCREENSHOT="/mnt/sdcard/MUOS/screenshot"
SD2_PICO8="/mnt/sdcard/MUOS/save/pico8"
SD2_PICO8_BIOS="/mnt/sdcard/MUOS/bios/pico8/"
SD2_PPSSPP_SAVE="/mnt/sdcard/MUOS/save/file/PPSSPP-Ext"
SD2_PPSSPP_STATE="/mnt/sdcard/MUOS/save/state/PPSSPP-Ext"
SD2_DRASTIC_SAVE="/mnt/sdcard/MUOS/save/drastic/backup"

# See if SD2 is mounted.
# Let's do this early in case it's not here.
if grep -m 1 "mmcblk1" /proc/partitions >/dev/null; then
	echo "SD Card 2 has been detected."
	echo -e "Continuing.\n"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo "SD Card 2 has been detected." >/tmp/muxlog_info
		echo -e "Continuing.\n" >/tmp/muxlog_info
	fi
else
	echo "SD Card 2 not detected."
	echo -e "Aborting!\n"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo "SD Card 2 not detected." >/tmp/muxlog_info
		echo -e "Aborting!\n" >/tmp/muxlog_info
	fi
	sleep 10
	exit 1
fi

# Create temporary directory
MUX_TEMP="/opt/muxtmp"
mkdir "$MUX_TEMP"

RSYNCLOG="/mnt/sdcard/migrate_log.txt"

# Initialize total size of folders to migrate
TOTAL_SIZE=0

# Get the size of a directory in MB
GET_SIZE() {
    du -sm "$1" | awk '{print $1}'
}

# Add sizes of individual directories
if [ -d $SD1_BIOS ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_BIOS")))
	echo "Size of BIOS Folder: $(GET_SIZE "$SD1_BIOS") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of BIOS Folder: $(GET_SIZE "$SD1_BIOS") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_CATALOGUE ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_CATALOGUE")))
	echo "Size of Catalogue Folder: $(GET_SIZE "$SD1_CATALOGUE") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of Catalogue Folder: $(GET_SIZE "$SD1_CATALOGUE") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_CONFIG ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_CONFIG")))
	echo "Size of Config Folder: $(GET_SIZE "$SD1_CONFIG") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of Config Folder: $(GET_SIZE "$SD1_CONFIG") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_LANGUAGE ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_LANGUAGE")))
	echo "Size of Language Folder: $(GET_SIZE "$SD1_LANGUAGE") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of Language Folder: $(GET_SIZE "$SD1_LANGUAGE") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_MUSIC ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_MUSIC")))
	echo "Size of Music Folder: $(GET_SIZE "$SD1_MUSIC") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of Music Folder: $(GET_SIZE "$SD1_MUSIC") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_NAME ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_NAME")))
	echo "Size of Name Folder: $(GET_SIZE "$SD1_NAME") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of Name Folder: $(GET_SIZE "$SD1_NAME") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_NETWORK ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_NETWORK")))
	echo "Size of Name Folder: $(GET_SIZE "$SD1_NETWORK") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of Name Folder: $(GET_SIZE "$SD1_NETWORK") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_SAVE ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_SAVE")))
	echo "Size of Save Folder: $(GET_SIZE "$SD1_SAVE") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of Save Folder: $(GET_SIZE "$SD1_SAVE") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_SCREENSHOT ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_SCREENSHOT")))
	echo "Size of Screenshot Folder: $(GET_SIZE "$SD1_SCREENSHOT") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of Screenshot Folder: $(GET_SIZE "$SD1_SCREENSHOT") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_THEME ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_THEME")))
	echo "Size of Theme Folder: $(GET_SIZE "$SD1_THEME") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of Theme Folder: $(GET_SIZE "$SD1_THEME") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_OPENBOR_SAVE ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_OPENBOR_SAVE")))
	echo "Size of OpenBOR Save Folder: $(GET_SIZE "$SD1_OPENBOR_SAVE") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of OpenBOR Save Folder: $(GET_SIZE "$SD1_OPENBOR_SAVE") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_OPENBOR_SCREENSHOT ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_OPENBOR_SCREENSHOT")))
	echo "Size of OpenBOR Screenshot Folder: $(GET_SIZE "$SD1_OPENBOR_SCREENSHOT") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of OpenBOR Screenshot Folder: $(GET_SIZE "$SD1_OPENBOR_SCREENSHOT") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_PICO8 ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_PICO8")))
	echo "Size of PICO-8 Folder: $(GET_SIZE "$SD1_PICO8") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of PICO-8 Folder: $(GET_SIZE "$SD1_PICO8") MB"\n" >/tmp/muxlog_info
	fi
fi

for PICOFILE in $SD1_PICO8_BIOS; do
	if [ -f $PICOFILE ]; then
		TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$PICOFILE")))
		echo "Size of $PICOFILE: $(GET_SIZE "$PICOFILE") MB"
		if [ $CURRENT_VER = "PREBANANA" ]; then
			echo -e ""Size of $PICOFILE: $(GET_SIZE "$PICOFILE") MB"\n" >/tmp/muxlog_info
		fi
	fi
done

if [ -d $SD1_PPSSPP_SAVE ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_PPSSPP_SAVE")))
	echo "Size of PPSSPP Save Folder: $(GET_SIZE "$SD1_PPSSPP_SAVE") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of PPSSPP Save Folder: $(GET_SIZE "$SD1_PPSSPP_SAVE") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_PPSSPP_STATE ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_PPSSPP_STATE")))
	echo "Size of PPSSPP State Folder: $(GET_SIZE "$SD1_PPSSPP_STATE") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of PPSSPP State Folder: $(GET_SIZE "$SD1_PPSSPP_STATE") MB"\n" >/tmp/muxlog_info
	fi
fi

if [ -d $SD1_DRASTIC_SAVE ]; then
	TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_DRASTIC_SAVE")))
	echo "Size of DraStic Save Folder: $(GET_SIZE "$SD1_DRASTIC_SAVE") MB"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e ""Size of DraStic Save Folder: $(GET_SIZE "$SD1_DRASTIC_SAVE") MB"\n" >/tmp/muxlog_info
	fi
fi

# Loop through SD1_CONTENT directories
for dir in $SD1_CONTENT; do
    TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$dir")))
	if [ $dir = "/mnt/mmc/MUOS/info/core" ]; then
		echo "Size of Core Folder: $(GET_SIZE "$dir") MB"
		if [ $CURRENT_VER = "PREBANANA" ]; then
			echo -e ""Size of Core Folder: $(GET_SIZE "$dir") MB"\n" >/tmp/muxlog_info
		fi
	elif [ $dir = "/mnt/mmc/MUOS/info/favourite" ]; then
		echo "Size of Favourite Folder: $(GET_SIZE "$dir") MB"
				if [ $CURRENT_VER = "PREBANANA" ]; then
			echo -e ""Size of Favourite Folder: $(GET_SIZE "$dir") MB"\n" >/tmp/muxlog_info
		fi
	else
		echo "Size of History Folder: $(GET_SIZE "$dir") MB"
				if [ $CURRENT_VER = "PREBANANA" ]; then
			echo -e ""Size of History Folder: $(GET_SIZE "$dir") MB"\n" >/tmp/muxlog_info
		fi
	fi
done
sleep 2

# Print the total size
echo -e "\nTotal size of folders to migrate: ${TOTAL_SIZE} MB"
if [ $CURRENT_VER = "PREBANANA" ]; then
	echo -e "\nTotal size of folders to migrate: ${TOTAL_SIZE} MB" >/tmp/muxlog_info
fi

# Check free space
SD_FREE_SPACE=$(df -m /mnt/sdcard | awk 'NR==2 {print $4}')
echo -e "Total free space on SD Card 2: ${SD_FREE_SPACE} MB\n"
if [ $CURRENT_VER = "PREBANANA" ]; then
	echo -e "Total free space on SD Card 2: ${SD_FREE_SPACE} MB\n" >/tmp/muxlog_info
fi

# Check if there is enough space before continuing
if [ $TOTAL_SIZE -lt $SD_FREE_SPACE ]; then
	echo -e "\nThere is enough free space for the migration."
	echo -e "Continuing.\n"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "\nThere is enough free space for the migration." >/tmp/muxlog_info
		echo -e "Continuing.\n" >/tmp/muxlog_info
	fi
else
	echo -e "\nThere is not enough free space for the migration!"
	echo "Aborting!"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "\nThere is not enough free space for the migration!" >/tmp/muxlog_info
		echo "Aborting!" >/tmp/muxlog_info
	fi
	sleep 10
	exit 1
fi

# Generate Exclusion List
# Add any additional files / folders you want to exclude in here.
cat <<EOF > $MUX_TEMP/sync_exclude.txt
.stfolder/
EOF

RSYNC_OPTS="--verbose --archive --checksum --exclude-from=$MUX_TEMP/sync_exclude.txt --log-file=$RSYNCLOG"

# Migrate all folders.
if [ -d $SD1_BIOS ]; then
	echo "Copying BIOS to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying BIOS to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_BIOS" "$SD2_BIOS"
fi

if [ -d $SD1_CATALOGUE ]; then
	echo -e "\nCopying Catalogue to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying Catalogue to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_CATALOGUE" "$SD2_CATALOGUE"
fi

if [ -d $SD1_CONFIG ]; then
	echo -e "\nCopying Config to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying Config to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_CONFIG" "$SD2_CONFIG"
fi

echo -e "\nCopying Content to SD Card 2"
if [ $CURRENT_VER = "PREBANANA" ]; then
	echo -e "Copying Content to SD Card 2\n" >/tmp/muxlog_info
fi
sleep 1
for DIR in $SD1_CONTENT; do
	if [ -d $DIR ]; then
		rsync $RSYNC_OPTS "$DIR" "$SD2_CONTENT"
	fi
done

if [ -d "$SD1_LANGUAGE" ]; then
	echo -e "\nCopying Language to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying Language to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_LANGUAGE" "$SD2_LANGUAGE"
else
	echo -e "\nNo language folder exists, skipping."
fi

if [ -d "$SD1_MUSIC" ]; then
	echo -e "\nCopying Music to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying Music to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_MUSIC" "$SD2_MUSIC"
else
	echo -e "\nNo music folder exists, skipping."
fi

if [ -d "$SD1_NAME" ]; then
	echo -e "\nCopying Names to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying Names to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_NAME" "$SD2_NAME"
else
	echo -e "\nNo names folder exists, skipping."
fi

if [ -d "$SD1_NETWORK" ]; then
	echo -e "\nCopying Network Profiles to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying Network Profiles to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_NETWORK" "$SD2_NETWORK"
else
	echo -e "\nNo Networl Profile folder exists, skipping."
fi

if [ -d $SD1_SAVE ]; then
	echo -e "\nCopying Saves to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying Saves to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_SAVE" "$SD2_SAVE"
fi

if [ -d $SD1_SCREENSHOT ]; then
	echo -e "\nCopying Screenshots to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying Screenshots to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_SCREENSHOT" "$SD2_SCREENSHOT"
fi

if [ -d $SD1_THEME ]; then
	# Migrate themes to SD2
	# Themes on Pre-Banana versions are not migrated due to theme engine changes.
	echo -e "\nCopying Themes to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Skipping theme migration to SD Card 2\n" >/tmp/muxlog_info
	else
		sleep 1
		rsync $RSYNC_OPTS "$SD1_THEME" "$SD2_THEME"
	fi
fi

if [ -d "$SD1_OPENBOR_SAVE" ]; then
	echo -e "\nCopying OpenBOR Saves and Screenshots to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying OpenBOR Saves to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_OPENBOR_SAVE" "$SD2_OPENBOR_SAVE"
	rsync $RSYNC_OPTS "$SD1_OPENBOR_SCREENSHOT" "$SD2_OPENBOR_SCREENSHOT"
else
	echo -e "\nNo OpenBOR folder exists, skipping."
fi

if [ -d $SD1_PICO8 ]; then
	echo -e "\nCopying PICO-8 Files to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying PICO-8 Files to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_PICO8" "$SD2_PICO8"
fi

for PICOFILE in $SD1_PICO8_BIOS; do
	if [ -f $PICOFILE ]; then
		echo -e "\nCopying PICO-8 Files to SD Card 2"
		if [ $CURRENT_VER = "PREBANANA" ]; then
			echo -e "Copying PICO-8 Files to SD Card 2\n" >/tmp/muxlog_info
		fi
		sleep 1
		rsync $RSYNC_OPTS "$PICOFILE" "$SD2_PICO8_BIOS"
	fi
done

echo -e "\nCopying PPSSPP Saves to SD Card 2"
if [ $CURRENT_VER = "PREBANANA" ]; then
	echo -e "Copying PPSSPP Saves to SD Card 2\n" >/tmp/muxlog_info
fi
sleep 1
if [ -d $SD1_PPSSPP_SAVE ]; then
	rsync $RSYNC_OPTS "$SD1_PPSSPP_SAVE" "$SD2_PPSSPP_SAVE"
fi

if [ -d $SD1_PPSSPP_STATE ]; then
	rsync $RSYNC_OPTS "$SD1_PPSSPP_STATE" "$SD2_PPSSPP_STATE"
fi

if [ -d $SD1_DRASTIC_SAVE ]; then
	echo -e "\nCopying DraStic Saves to SD Card 2"
	if [ $CURRENT_VER = "PREBANANA" ]; then
		echo -e "Copying DraStic Saves to SD Card 2\n" >/tmp/muxlog_info
	fi
	sleep 1
	rsync $RSYNC_OPTS "$SD1_DRASTIC_SAVE" "$SD2_DRASTIC_SAVE"
fi

# Set muOS Storage Pref to AUTO
# Using AUTO instead of SD2 ensures it keeps working if they remove SD2
MU_PATH="/run/muos/global/storage"
MU_STORAGE_PREF="bios catalogue config content music save screenshot theme"

if [ -d "$MU_PATH" ]; then
	echo "Setting Storage Preference to AUTO"
	for PREF in $MU_STORAGE_PREF; do
		printf "%d" 2 > $MU_PATH/$PREF
	done
else
	# Pre-BANANA muOS won't need this done.
	echo "Previous MUOS version detected."
	echo "Storage Preference change not required."
	exit 0
fi

# Sync Filesystem
echo -e "Syncing Filesystem\n"
if [ $CURRENT_VER = "PREBANANA" ]; then
	echo -e "Copying Syncing Filesystem\n" >/tmp/muxlog_info
fi
sync

# Clean Up
if [ $CURRENT_VER = "PREBANANA" ]; then
	killall -q muxlog
	rm -rf "$MUX_TEMP" /tmp/muxlog_*
fi
rm -rf "$MUX_TEMP"
