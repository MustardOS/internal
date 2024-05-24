#!/bin/sh
# shellcheck disable=1090,2002,2009

MUOSBOOT_LOG=$1

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

CURRENT_DATE=$(date +"%Y_%m_%d__%H_%M_%S")

ROM_PARTITION=7

LOGGER() {
VERBOSE=$(parse_ini "$CONFIG" "settings.advanced" "verbose")
if [ "$VERBOSE" -eq 1 ]; then
	_TITLE=$1
	_MESSAGE=$2
	_FORM=$(cat <<EOF
$_TITLE

$_MESSAGE
EOF
	)
	/opt/muos/extra/muxstart "$_FORM" && sleep 0.5
	echo "=== ${CURRENT_DATE} === $_MESSAGE" >> "$MUOSBOOT_LOG"
fi
}

umount /mnt/mmc

LOGGER "FACTORY RESET" "Expanding SD1 ROM Partition"
printf "w\nw\n" | fdisk /dev/mmcblk0
parted ---pretend-input-tty /dev/mmcblk0 resizepart "$ROM_PARTITION" 100%

LOGGER "FACTORY RESET" "Formatting SD1 ROM Partition"
mkfs.exfat /dev/mmcblk0p"$ROM_PARTITION"
exfatlabel /dev/mmcblk0p"$ROM_PARTITION" ROMS

LOGGER "FACTORY RESET" "Setting SD1 ROM Partition Flags"
parted ---pretend-input-tty /dev/mmcblk0 set "$ROM_PARTITION" boot off
parted ---pretend-input-tty /dev/mmcblk0 set "$ROM_PARTITION" hidden off

LOGGER "FACTORY RESET" "Restoring SD1 ROM Filesystem"
mount -t exfat /dev/mmcblk0p"$ROM_PARTITION" /mnt/mmc

RSRF="Restoring SD1 ROM Filesystem"
LOGGER "FACTORY RESET" "$RSRF"

if [ "$(cat /opt/muos/config/device.txt)" != "RG28XX" ] || [ "$(cat /opt/muos/config/device.txt)" != "RG35XX-2024" ]; then
	rm -rf /opt/muos/init/MUOS/PortMaster
fi

mv /opt/muos/init/* /mnt/mmc/ &

while true; do
	IS_WORKING=$(ps aux | grep '[m]v' | awk '{print $1}')
	RANDOM_LINE=$(awk 'BEGIN{srand();} {if (rand() < 1/NR) selected=$0} END{print selected}' /opt/muos/config/messages.txt)

	LOGGER "$RSRF" "$RANDOM_LINE"

	if [ "$IS_WORKING" = "" ]; then
		break
	fi

	sleep 5
done

rm -rf /opt/muos/init &

EXTRACT_ARCHIVE() {
	ARCHIVE="$1"
	DESTINATION="$2"
	WHAT="$3"

	RSRF="Merging $WHAT Archive"
	LOGGER "FACTORY RESET" "$RSRF"

	zip -s0 "$ARCHIVE" --out /tmp/mux_archive.zip

	RSRF="Restoring $WHAT"
	LOGGER "FACTORY RESET" "$RSRF"

	unzip -o /tmp/mux_archive.zip -d "$DESTINATION" &

	while true; do
		IS_WORKING=$(ps aux | grep '[u]nzip' | awk '{print $1}')
		RANDOM_LINE=$(awk 'BEGIN{srand();} {if (rand() < 1/NR) selected=$0} END{print selected}' /opt/muos/config/messages.txt)

		LOGGER "$RSRF" "$RANDOM_LINE"

		if [ -z "$IS_WORKING" ]; then
			break
		fi

		sleep 5
	done

	rm /tmp/mux_archive.zip
}

EXTRACT_ARCHIVE "/opt/muos/archive/libretro/libretro.zip" "/mnt/mmc/MUOS/core/" "Libretro Cores"

if [ "$(cat /opt/muos/config/device.txt)" != "RG28XX" ] || [ "$(cat /opt/muos/config/device.txt)" != "RG35XX-2024" ]; then
	EXTRACT_ARCHIVE "/opt/muos/archive/portmaster/portmaster.zip" "/mnt/mmc/MUOS/PortMaster/" "PortMaster"
fi

EXTRACT_ARCHIVE "/opt/muos/archive/soundfont/soundfont.zip" "/usr/share/soundfonts/" "Soundfonts"

if [ "$(cat /opt/muos/config/device.txt)" != "RG28XX" ] || [ "$(cat /opt/muos/config/device.txt)" != "RG35XX-2024" ]; then
	LOGGER "FACTORY RESET" "Changing Network MAC Address"
	macchanger -r wlan0
	macchanger -r wlan1
fi

if [ "$(cat /opt/muos/config/device.txt)" != "RG28XX" ] || [ "$(cat /opt/muos/config/device.txt)" != "RG35XX-2024" ]; then
	LOGGER "FACTORY RESET" "Setting Random Hostname"
	hostname "$(hostname)-$(cat /proc/sys/kernel/random/uuid | head -c 5)"
fi

LOGGER "FACTORY RESET" "Syncing Partitions"
sync

