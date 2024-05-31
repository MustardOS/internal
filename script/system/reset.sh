#!/bin/sh

MUOSBOOT_LOG=$1

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

SUPPORT_PORTMASTER=$(parse_ini "$DEVICE_CONFIG" "device" "portmaster")
SUPPORT_NETWORK=$(parse_ini "$DEVICE_CONFIG" "device" "network")
NET_IFACE=$(parse_ini "$DEVICE_CONFIG" "network" "iface")

CURRENT_DATE=$(date +"%Y_%m_%d__%H_%M_%S")

ROM_DEVICE=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "dev")
ROM_PARTITION=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "num")
ROM_MOUNT=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
ROM_TYPE=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "type")

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

umount /"$ROM_MOUNT"

LOGGER "FACTORY RESET" "Expanding ROM Partition"
printf "w\nw\n" | fdisk /dev/"$ROM_DEVICE"
parted ---pretend-input-tty /dev/"$ROM_DEVICE" resizepart "$ROM_PARTITION" 100%

LOGGER "FACTORY RESET" "Formatting ROM Partition"
mkfs."${ROM_TYPE}" /dev/"$ROM_DEVICE"p"$ROM_PARTITION"
case "$ROM_TYPE" in
	vfat | exfat)
		exfatlabel /dev/"$ROM_DEVICE"p"$ROM_PARTITION" ROMS
		;;
	ext4)
		e2label /dev/"$ROM_DEVICE"p"$ROM_PARTITION" ROMS
		;;
esac

LOGGER "FACTORY RESET" "Setting ROM Partition Flags"
parted ---pretend-input-tty /dev/"$ROM_DEVICE" set "$ROM_PARTITION" boot off
parted ---pretend-input-tty /dev/"$ROM_DEVICE" set "$ROM_PARTITION" hidden off

LOGGER "FACTORY RESET" "Restoring ROM Filesystem"
mount -t "$ROM_TYPE" /dev/"$ROM_DEVICE"p"$ROM_PARTITION" /"$ROM_MOUNT"

RSRF="Restoring ROM Filesystem"
LOGGER "FACTORY RESET" "$RSRF"

if [ "$SUPPORT_PORTMASTER" -eq 0 ]; then
	rm -rf /opt/muos/init/MUOS/PortMaster
fi

mv /opt/muos/init/* /"$ROM_MOUNT"/ &

while true; do
	IS_WORKING=$(pgrep -f "mv")
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
		IS_WORKING=$(pgrep -f "unzip")
		RANDOM_LINE=$(awk 'BEGIN{srand();} {if (rand() < 1/NR) selected=$0} END{print selected}' /opt/muos/config/messages.txt)

		LOGGER "$RSRF" "$RANDOM_LINE"

		if [ -z "$IS_WORKING" ]; then
			break
		fi

		sleep 5
	done

	rm /tmp/mux_archive.zip
}

EXTRACT_ARCHIVE "/opt/muos/archive/libretro/libretro.zip" "/$ROM_MOUNT/MUOS/core/" "Libretro Cores"

if [ "$SUPPORT_PORTMASTER" -eq 1 ]; then
	EXTRACT_ARCHIVE "/opt/muos/archive/portmaster/portmaster.zip" "/$ROM_MOUNT/MUOS/PortMaster/" "PortMaster"
fi

EXTRACT_ARCHIVE "/opt/muos/archive/soundfont/soundfont.zip" "/usr/share/soundfonts/" "Soundfonts"

if [ "$SUPPORT_NETWORK" -eq 1 ]; then
	LOGGER "FACTORY RESET" "Changing Network MAC Address"
	macchanger -r "$NET_IFACE"

	LOGGER "FACTORY RESET" "Setting Random Hostname"
	HN=$(hostname)-$(head -c 5 /proc/sys/kernel/random/uuid)
	hostname "$HN"
	echo "$HN" > /etc/hostname
fi

LOGGER "FACTORY RESET" "Syncing Partitions"
sync

