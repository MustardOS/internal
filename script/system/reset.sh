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

PROGRESS_FILE="/tmp/msg_progress"
UD_ARCHIVE="/opt/muos/init/userdata.tar.gz"
TOTAL=$(wc -c <"$UD_ARCHIVE")

printf 0 >"$PROGRESS_FILE"

(
	/opt/muos/bin/pv -n -f -s "$TOTAL" "$UD_ARCHIVE" 2>&1 1>&3 |
		while IFS= read -r PERCENT; do
			printf "%s" "$PERCENT" >"$PROGRESS_FILE"
		done
) 3>&1 | gzip -dc | tar -xf - -C "$ROM_MOUNT"

LOG_INFO "$0" 0 "FACTORY RESET" "ROM Restore Complete"
printf 100 >"$PROGRESS_FILE"

LOG_INFO "$0" 0 "FACTORY RESET" "Generating Filesystem Paths"
MUOS_DIR="$ROM_MOUNT/MUOS"
DIRS='
info/catalogue
info/collection
info/history
info/name
info/track
init
log/boot
log/dmesg
log/retroarch
network
package/catalogue
package/config
save/drastic/backup
save/drastic/savestates
save/drastic-legacy/backup
save/drastic-legacy/savestates
save/file/OpenBOR-Ext
save/file/PPSSPP-Ext
save/file/YabaSanshiro-Ext
save/pico8/bbs
save/pico8/cdata
save/pico8/cstore
save/pico8/desktop
save/state/PPSSPP-Ext
save/state/YabaSanshiro-Ext
screenshot
syncthing
'

for D in $DIRS; do
	mkdir -p "$MUOS_DIR/$D"
done

LOG_INFO "$0" 0 "FACTORY RESET" "Generating Default RetroArch Config Archive"
ARCHIVE="$MUOS_DIR/package/config/MustardOS Default.muxcfg"
SRC_DIR="/opt/muos/share/info/config"
(cd "$SRC_DIR" && zip -r -9 -q -y -X "$ARCHIVE" .)

LOG_INFO "$0" 0 "FACTORY RESET" "Copying Default Friendly Name Files"
SRC_DIR="/opt/muos/share/info"
DST_DIR="$MUOS_DIR/info"
cp -f "$SRC_DIR"/name/* "$DST_DIR/name/"
cp -f "$SRC_DIR"/pass.ini "$SRC_DIR"/skip.ini "$DST_DIR/"

LOG_INFO "$0" 0 "FACTORY RESET" "Generating Blank Syncthing API File"
: >"$MUOS_DIR/syncthing/api.txt"

LOG_INFO "$0" 0 "FACTORY RESET" "Calculating FNV-1a Hash of Default Theme"
/opt/muos/bin/fnv1a "$MUOS_DIR/theme/MustardOS.muxthm" >"/opt/muos/config/theme/default"

LOG_INFO "$0" 0 "FACTORY RESET" "Decompressing PortMaster Application"
unzip -oq "/opt/muos/share/archive/muos.portmaster.zip" -d /

LOG_INFO "$0" 0 "FACTORY RESET" "Generating Automatic Core Assign"
/opt/muos/script/system/assign.sh -p -v

if [ "$NETWORK_ENABLED" -eq 1 ]; then
	LOG_INFO "$0" 0 "FACTORY RESET" "Changing Network MAC Address"
	macchanger -r "$NET_IFACE"

	LOG_INFO "$0" 0 "FACTORY RESET" "Setting Hostname"
	HN="$(hostname)-$(/opt/muos/script/system/serial.sh | tail -c 6)"
	hostname "$HN"
	printf "%s" "$HN" >/etc/hostname
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Syncing Partitions"
sync
