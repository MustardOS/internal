#!/bin/sh

. /opt/muos/script/var/func.sh

ROM_DEV="$(GET_VAR "device" "storage/rom/dev")"
ROM_SEP="$(GET_VAR "device" "storage/rom/sep")"
ROM_NUM="$(GET_VAR "device" "storage/rom/num")"
ROM_TYPE="$(GET_VAR "device" "storage/rom/type")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"

NETWORK_ENABLED="$(GET_VAR "device" "board/network")"
NET_IFACE="$(GET_VAR "device" "network/iface")"

ROM_PART="/dev/${ROM_DEV}${ROM_SEP}${ROM_NUM}"

LOG_INFO "$0" 0 "FACTORY RESET" "Expanding ROM Partition"
printf "w\nw\n" | fdisk /dev/"$ROM_DEV"
parted ---pretend-input-tty /dev/"$ROM_DEV" resizepart "$ROM_NUM" 100%

LOG_INFO "$0" 0 "FACTORY RESET" "Formatting ROM Partition"
mkfs."$ROM_TYPE" "$ROM_PART"
case "$ROM_TYPE" in
	vfat | exfat) exfatlabel "$ROM_PART" ROMS ;;
esac

LOG_INFO "$0" 0 "FACTORY RESET" "Setting ROM Partition Flags"
parted ---pretend-input-tty /dev/"$ROM_DEV" set "$ROM_NUM" boot off
parted ---pretend-input-tty /dev/"$ROM_DEV" set "$ROM_NUM" hidden off
parted ---pretend-input-tty /dev/"$ROM_DEV" set "$ROM_NUM" msftdata on

LOG_INFO "$0" 0 "FACTORY RESET" "Mounting ROM Partition"
if mount -t "$ROM_TYPE" -o rw,utf8,noatime,nofail "$ROM_PART" "$ROM_MOUNT"; then
	SET_VAR "device" "storage/rom/active" "1"
else
	killall -q "mpv"
	CRITICAL_FAILURE device "$ROM_MOUNT" "$ROM_PART"
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Restoring ROM Filesystem"

INIT_SRC="/opt/muos/init"
PROGRESS_FILE="/tmp/msg_progress"

TMP_LIST="/tmp/file_list.txt"
: >"$TMP_LIST"

find "$INIT_SRC" -type f >"$TMP_LIST"
TOTAL=$(wc -l <"$TMP_LIST")
COUNT=0
LAST_PERCENT=-1

rsync --archive --whole-file --remove-source-files --itemize-changes \
	"$INIT_SRC/" "$ROM_MOUNT"/ 2>/dev/null |
	while IFS= read -r LINE; do
		case "$LINE" in
			[\>f]*)
				COUNT=$((COUNT + 1))
				PERCENT=$((COUNT * 1000 / TOTAL))
				PERCENT=$((PERCENT / 10))

				if [ "$PERCENT" -ne "$LAST_PERCENT" ]; then
					printf "%s\n" "$PERCENT" >"$PROGRESS_FILE"
					LAST_PERCENT=$PERCENT
				fi
				;;
		esac
	done

rm -rf "$INIT_SRC"
echo 100 >"$PROGRESS_FILE"

/opt/muos/bin/toybox sleep 5
touch "/tmp/msg_finish"

LOG_INFO "$0" 0 "FACTORY RESET" "Purging Init Directory"
rm -rf /opt/muos/init

LOG_INFO "$0" 0 "FACTORY RESET" "Binding Storage Mounts"
/opt/muos/script/mount/bind.sh >/dev/null

if [ "$NETWORK_ENABLED" -eq 1 ]; then
	LOG_INFO "$0" 0 "FACTORY RESET" "Changing Network MAC Address"
	macchanger -r "$NET_IFACE"

	LOG_INFO "$0" 0 "FACTORY RESET" "Setting Hostname"
	HN="$(hostname)-$(/opt/muos/script/system/serial.sh | tail -c 6)"
	hostname "$HN"
	echo "$HN" >/etc/hostname
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Syncing Partitions"
sync
