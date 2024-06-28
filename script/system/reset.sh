#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/device.sh
. /opt/muos/script/var/device/network.sh
. /opt/muos/script/var/device/storage.sh

umount "$DC_STO_ROM_MOUNT"

LOGGER "FACTORY RESET" "Expanding ROM Partition"
printf "w\nw\n" | fdisk /dev/"$DC_STO_ROM_DEV"
parted ---pretend-input-tty /dev/"$DC_STO_ROM_DEV" resizepart "$DC_STO_ROM_NUM" 100%

LOGGER "FACTORY RESET" "Formatting ROM Partition"
mkfs."${DC_STO_ROM_TYPE}" /dev/"$DC_STO_ROM_DEV"p"$DC_STO_ROM_NUM"
case "$DC_STO_ROM_TYPE" in
	vfat | exfat)
		exfatlabel /dev/"$DC_STO_ROM_DEV"p"$DC_STO_ROM_NUM" ROMS
		;;
	ext4)
		e2label /dev/"$DC_STO_ROM_DEV"p"$DC_STO_ROM_NUM" ROMS
		;;
esac

LOGGER "FACTORY RESET" "Setting ROM Partition Flags"
parted ---pretend-input-tty /dev/"$DC_STO_ROM_DEV" set "$DC_STO_ROM_NUM" boot off
parted ---pretend-input-tty /dev/"$DC_STO_ROM_DEV" set "$DC_STO_ROM_NUM" hidden off

LOGGER "FACTORY RESET" "Restoring ROM Filesystem"
mount -t "$DC_STO_ROM_TYPE" /dev/"$DC_STO_ROM_DEV"p"$DC_STO_ROM_NUM" "$DC_STO_ROM_MOUNT"

LOGGER "FACTORY RESET" "Restoring ROM Filesystem"
mv /opt/muos/init/* "$DC_STO_ROM_MOUNT"/ &

while true; do
	IS_WORKING=$(pgrep -f "mv")
	RANDOM_LINE=$(awk 'BEGIN{srand();} {if (rand() < 1/NR) selected=$0} END{print selected}' /opt/muos/config/messages.txt)

	MSG=$(
		cat <<EOF
FACTORY RESET

$RANDOM_LINE
EOF
	)
	/opt/muos/extra/muxstart "$MSG" && sleep 0.5

	if [ "$IS_WORKING" = "" ]; then
		break
	fi

	sleep 5
done

LOGGER "$0" "FACTORY RESET" "Restoring PortMaster"
cp -r /opt/muos/archive/portmaster/* "$DC_STO_ROM_MOUNT"/MUOS/PortMaster/

LOGGER "$0" "FACTORY RESET" "Purging init directory"
rm -rf /opt/muos/init

if [ "$DC_DEV_NETWORK" -eq 1 ]; then
	LOGGER "$0" "FACTORY RESET" "Changing Network MAC Address"
	macchanger -r "$DC_NET_INTERFACE"

	LOGGER "$0" "FACTORY RESET" "Setting Random Hostname"
	HN=$(hostname)-$(head -c 5 /proc/sys/kernel/random/uuid)
	hostname "$HN"
	echo "$HN" >/etc/hostname
fi

LOGGER "$0" "FACTORY RESET" "Syncing Partitions"
sync
