#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "FACTORY RESET" "Expanding ROM Partition"
printf "w\nw\n" | fdisk /dev/"$(GET_VAR "device" "storage/rom/dev")"
parted ---pretend-input-tty /dev/"$(GET_VAR "device" "storage/rom/dev")" resizepart "$(GET_VAR "device" "storage/rom/num")" 100%

LOG_INFO "$0" 0 "FACTORY RESET" "Formatting ROM Partition"
mkfs."$(GET_VAR "device" "storage/rom/type")" /dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")"
case "$(GET_VAR "device" "storage/rom/type")" in
	vfat | exfat)
		exfatlabel /dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")" ROMS
		;;
	ext4)
		e2label /dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")" ROMS
		;;
esac

LOG_INFO "$0" 0 "FACTORY RESET" "Setting ROM Partition Flags"
parted ---pretend-input-tty /dev/"$(GET_VAR "device" "storage/rom/dev")" set "$(GET_VAR "device" "storage/rom/num")" boot off
parted ---pretend-input-tty /dev/"$(GET_VAR "device" "storage/rom/dev")" set "$(GET_VAR "device" "storage/rom/num")" hidden off
parted ---pretend-input-tty /dev/"$(GET_VAR "device" "storage/rom/dev")" set "$(GET_VAR "device" "storage/rom/num")" msftdata on

LOG_INFO "$0" 0 "FACTORY RESET" "Mounting ROM Partition"
if mount -t "$(GET_VAR "device" "storage/rom/type")" -o rw,utf8,noatime,nofail \
	/dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")" \
	"$(GET_VAR "device" "storage/rom/mount")"; then
	SET_VAR "device" "storage/rom/active" "1"
else
	killall -q "mpv"
	CRITICAL_FAILURE device "$(GET_VAR "device" "storage/rom/mount")" "/dev/$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")"
fi

PROGRESS_DIALOG() {
	I=0
	while read -r PROGRESS; do
		if [ "$I" -eq 0 ]; then
			MESSAGE=$(awk 'BEGIN{srand();} {if (rand() < 1/NR) selected=$0} END{print selected}' /opt/muos/config/messages.txt)
		fi
		I="$(((I + 1) % 4))"
		/opt/muos/extra/muxstart "$PROGRESS" "$(printf "INSTALLING MUOS\n\n%s\n" "$MESSAGE")"
	done
}

RESTORE_ROM_FS() {
	LOG_INFO "$0" 0 "FACTORY RESET" "Restoring ROM Filesystem"
	rsync --archive --checksum --remove-source-files --itemize-changes --outbuf=L /opt/muos/init/ "$(GET_VAR "device" "storage/rom/mount")"/ 2>/dev/null |
		/opt/muos/bin/pv -nls "$(find /opt/muos/init -type f | wc -l)" 2>&1 >/dev/null |
		PROGRESS_DIALOG
}

LOG_INFO "$0" 0 "FACTORY RESET" "Checking Init Directory"
if [ "$(find /opt/muos/init -type f | wc -l)" -gt 0 ]; then
	RESTORE_ROM_FS
	sleep 1
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Purging Init Directory"
rm -rf /opt/muos/init

LOG_INFO "$0" 0 "FACTORY RESET" "Binding Storage Mounts"
/opt/muos/script/var/init/storage.sh

if [ "$(GET_VAR "device" "board/network")" -eq 1 ]; then
	LOG_INFO "$0" 0 "FACTORY RESET" "Changing Network MAC Address"
	macchanger -r "$(GET_VAR "device" "network/iface")"

	LOG_INFO "$0" 0 "FACTORY RESET" "Setting Hostname"
	HN="$(hostname)-$(/opt/muos/script/system/serial.sh | tail -c 9)"
	hostname "$HN"
	echo "$HN" >/etc/hostname
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Syncing Partitions"
sync
