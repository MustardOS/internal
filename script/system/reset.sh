#!/bin/sh

. /opt/muos/script/var/func.sh

umount "$(GET_VAR "device" "storage/rom/mount")"

LOGGER "FACTORY RESET" "Expanding ROM Partition"
printf "w\nw\n" | fdisk /dev/"$(GET_VAR "device" "storage/rom/dev")"
parted ---pretend-input-tty /dev/"$(GET_VAR "device" "storage/rom/dev")" resizepart "$(GET_VAR "device" "storage/rom/num")" 100%

LOGGER "FACTORY RESET" "Formatting ROM Partition"
mkfs."$(GET_VAR "device" "storage/rom/type")" /dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")"
case "$(GET_VAR "device" "storage/rom/type")" in
	vfat | exfat)
		exfatlabel /dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")" ROMS
		;;
	ext4)
		e2label /dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")" ROMS
		;;
esac

LOGGER "FACTORY RESET" "Setting ROM Partition Flags"
parted ---pretend-input-tty /dev/"$(GET_VAR "device" "storage/rom/dev")" set "$(GET_VAR "device" "storage/rom/num")" boot off
parted ---pretend-input-tty /dev/"$(GET_VAR "device" "storage/rom/dev")" set "$(GET_VAR "device" "storage/rom/num")" hidden off
parted ---pretend-input-tty /dev/"$(GET_VAR "device" "storage/rom/dev")" set "$(GET_VAR "device" "storage/rom/num")" msftdata on

LOGGER "FACTORY RESET" "Restoring ROM Filesystem"
mount -t "$(GET_VAR "device" "storage/rom/type")" /dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")" "$(GET_VAR "device" "storage/rom/mount")"

LOGGER "FACTORY RESET" "Restoring ROM Filesystem"
mv /opt/muos/init/* "$(GET_VAR "device" "storage/rom/mount")"/ &

while pgrep -f "mv" > /dev/null; do
    RANDOM_LINE=$(awk 'BEGIN{srand();} {if (rand() < 1/NR) selected=$0} END{print selected}' /opt/muos/config/messages.txt)
    /opt/muos/extra/muxstart "$(printf "FACTORY RESET\n\n%s\n" "$RANDOM_LINE")"
    sleep 5
done

LOGGER "$0" "FACTORY RESET" "Restoring PortMaster"
cp -r /opt/muos/archive/portmaster/* "$(GET_VAR "device" "storage/rom/mount")"/MUOS/PortMaster/

LOGGER "$0" "FACTORY RESET" "Purging init directory"
rm -rf /opt/muos/init

if [ "$(GET_VAR "device" "board/network")" -eq 1 ]; then
	LOGGER "$0" "FACTORY RESET" "Changing Network MAC Address"
	macchanger -r "$(GET_VAR "device" "network/iface")"

	LOGGER "$0" "FACTORY RESET" "Setting Random Hostname"
	HN=$(hostname)-$(head -c 5 /proc/sys/kernel/random/uuid)
	hostname "$HN"
	echo "$HN" >/etc/hostname
fi

LOGGER "$0" "FACTORY RESET" "Syncing Partitions"
sync
