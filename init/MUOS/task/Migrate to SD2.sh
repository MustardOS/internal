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

# Define all moveable storage locations.
SD1_BIOS="/mnt/mmc/MUOS/bios"
SD1_CATALOGUE="/mnt/mmc/MUOS/info/catalogue"
SD1_CONFIG="/mnt/mmc/MUOS/info/config"
SD1_CONTENT="/mnt/mmc/MUOS/info/core /mnt/mmc/MUOS/info/favourite /mnt/mmc/MUOS/info/history"
SD1_LANGUAGE="/mnt/mmc/MUOS/language"
SD1_MUSIC="/mnt/mmc/MUOS/music"
SD1_NAME="/mnt/mmc/MUOS/info/name"
SD1_SAVE="/mnt/mmc/MUOS/save"
SD1_SCREENSHOT="/mnt/mmc/MUOS/screenshot"
SD1_THEME="/mnt/mmc/MUOS/theme"

# Define all target locations
SD2_BIOS="/mnt/sdcard/MUOS"
SD2_CATALOGUE="/mnt/sdcard/MUOS/info"
SD2_CONFIG="/mnt/sdcard/MUOS/info"
SD2_CONTENT="/mnt/sdcard/MUOS/info"
SD2_LANGUAGE="/mnt/mmc/MUOS"
SD2_MUSIC="/mnt/sdcard/MUOS"
SD2_NAME="/mnt/mmc/MUOS/info"
SD2_SAVE="/mnt/sdcard/MUOS"
SD2_SCREENSHOT="/mnt/sdcard/MUOS"
SD2_THEME="/mnt/sdcard/MUOS"

# See if SD2 is mounted.
# Let's do this early in case it's not here.
if grep -m 1 "mmcblk1" /proc/partitions >/dev/null; then
	echo "SD Card 2 has been detected."
	echo -e "Continuing.\n"
else
	echo "SD Card 2 not detected."
	echo -e "Aborting!\n"
	sleep 10
	exit 1
fi

# Initialize total size of folders to migrate
TOTAL_SIZE=0

# Get the size of a directory in MB
GET_SIZE() {
    du -sm "$1" | awk '{print $1}'
}

# Add sizes of individual directories
TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_BIOS")))
echo "Size of BIOS Folder: $(GET_SIZE "$SD1_BIOS") MB"
TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_CATALOGUE")))
echo "Size of Catalogue Folder: $(GET_SIZE "$SD1_CATALOGUE") MB"
TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_CONFIG")))
echo "Size of Config Folder: $(GET_SIZE "$SD1_CONFIG") MB"
TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_LANGUAGE")))
echo "Size of Music Folder: $(GET_SIZE "$SD1_LANGUAGE") MB"
TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_MUSIC")))
echo "Size of Music Folder: $(GET_SIZE "$SD1_MUSIC") MB"
TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_NAME")))
echo "Size of Save Folder: $(GET_SIZE "$SD1_NAME") MB"
TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_SAVE")))
echo "Size of Save Folder: $(GET_SIZE "$SD1_SAVE") MB"
TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_SCREENSHOT")))
echo "Size of Screenshot Folder: $(GET_SIZE "$SD1_SCREENSHOT") MB"
TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$SD1_THEME")))
echo "Size of Theme Folder: $(GET_SIZE "$SD1_THEME") MB"

# Loop through SD1_CONTENT directories
for dir in $SD1_CONTENT; do
    TOTAL_SIZE=$((TOTAL_SIZE + $(GET_SIZE "$dir")))
	if [ $dir = "/mnt/mmc/MUOS/info/core" ]; then
		echo "Size of Core Folder: $(GET_SIZE "$dir") MB"
	elif [ $dir = "/mnt/mmc/MUOS/info/favourite" ]; then
		echo "Size of Favourite Folder: $(GET_SIZE "$dir") MB"
	else
		echo "Size of History Folder: $(GET_SIZE "$dir") MB"
	fi
done

# Print the total size
echo -e "\nTotal size of folders to migrate: ${TOTAL_SIZE} MB"

# Check free space
SD_FREE_SPACE=$(df -m /mnt/sdcard | awk 'NR==2 {print $4}')
echo -e "Total free space on SD Card 2: ${SD_FREE_SPACE} MB\n"

# Check if there is enough space before continuing
if [ $TOTAL_SIZE -lt $SD_FREE_SPACE ]; then
	echo -e "\nThere is enough free space for the migration."
	echo -e "Continuing.\n"
else
	echo -e "\nThere is not enough free space for the migration!"
	echo "Aborting!"
	sleep 10
	exit 1
fi

# Migrate all folders.
echo "Copying BIOS to SD Card 2"
sleep 1
rsync --verbose --archive --checksum "$SD1_BIOS" "$SD2_BIOS"

echo -e "\nCopying Catalogue to SD Card 2"
sleep 1
rsync --verbose --archive --checksum "$SD1_CATALOGUE" "$SD2_CATALOGUE"

echo -e "\nCopying Config to SD Card 2"
sleep 1
rsync --verbose --archive --checksum "$SD1_CONFIG" "$SD2_CONFIG"

echo -e "\nCopying Content to SD Card 2"
sleep 1
for DIR in $SD1_CONTENT; do
	rsync --verbose --archive --checksum "$DIR" "$SD2_CONTENT"
done

if [ -d "$SD1_LANGUAGE" ]; then
	echo -e "\nCopying Language to SD Card 2"
	sleep 1
	rsync --verbose --archive --checksum "$SD1_LANGUAGE" "$SD2_LANGUAGE"
else
	echo -e "\nNo language folder exists, skipping."
fi

if [ -d "$SD1_MUSIC" ]; then
	echo -e "\nCopying Music to SD Card 2"
	sleep 1
	rsync --verbose --archive --checksum "$SD1_MUSIC" "$SD2_MUSIC"
else
	echo -e "\nNo music folder exists, skipping."
fi

if [ -d "$SD1_NAMES" ]; then
	echo -e "\nCopying Names to SD Card 2"
	sleep 1
	rsync --verbose --archive --checksum "$SD1_NAME" "$SD2_NAME"
else
	echo -e "\nNo names folder exists, skipping."
fi

echo -e "\nCopying Save to SD Card 2"
sleep 1
rsync --verbose --archive --checksum "$SD1_SAVE" "$SD2_SAVE"

echo -e "\nCopying Screenshot to SD Card 2"
sleep 1
rsync --verbose --archive --checksum "$SD1_SCREENSHOT" "$SD2_SCREENSHOT"

echo -e "\nCopying Theme to SD Card 2"
sleep 1
rsync --verbose --archive --checksum "$SD1_THEME" "$SD2_THEME"

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
