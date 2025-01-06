#!/bin/sh

. /opt/muos/script/var/func.sh

# Storage locations within the MUOS directory that need to be central bind mounted
STORAGE_LOCS="bios init info/catalogue info/name retroarch info/config info/controller info/core info/collection info/history music save screenshot theme language network syncthing package/catalogue package/config"

# Unmount storage before remounting (e.g., on SD card insert/eject).
if [ -f /run/muos/storage/mounted ]; then
	for S_LOC in $STORAGE_LOCS; do
		umount -q "/run/muos/storage/$S_LOC"
	done
fi

# Shouldn't need to touch any of the below logic unless a critical failure occurs!
S_=0

for _ in $STORAGE_LOCS; do
	S_LOC=$(echo "$STORAGE_LOCS" | cut -d' ' -f$((S_ + 1)))

	mkdir -p "/run/muos/storage/$S_LOC"

	MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
	if ! mount --bind "$MOUNT/MUOS/$S_LOC" "/run/muos/storage/$S_LOC"; then
		MOUNT="$(GET_VAR "device" "storage/rom/mount")"
		if ! mount --bind "$MOUNT/MUOS/$S_LOC" "/run/muos/storage/$S_LOC"; then
			CRITICAL_FAILURE directory "$S_LOC" "$MOUNT"
		fi
	fi

	S_=$((S_ + 1))
done

# Bind hardcoded paths on SD1's ROM partition (where we can't use symlinks) to
# subdirs of the appropriate locations under /run/muos/storage (bound above).
BIND_EMULATOR() {
	TARGET="/run/muos/storage/$1"
	MOUNT="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/$2"
	[ -f /run/muos/storage/mounted ] && umount -q "$MOUNT"
	mkdir -p "$TARGET" "$MOUNT"
	mount --bind "$TARGET" "$MOUNT" || CRITICAL_FAILURE directory "$TARGET" "$MOUNT"
}

# Drastic Legacy
BIND_EMULATOR save/drastic-legacy/backup drastic-legacy/backup
BIND_EMULATOR save/drastic-legacy/savestates drastic-legacy/savestates

# OpenBOR
BIND_EMULATOR save/file/OpenBOR-Ext openbor/userdata/saves/openbor
BIND_EMULATOR screenshot openbor/userdata/screenshots/openbor

# PICO-8
BIND_EMULATOR "save/pico8" "pico8/.lexaloffle/pico-8"

# PPSSPP
BIND_EMULATOR save/file/PPSSPP-Ext ppsspp/.config/ppsspp/PSP/SAVEDATA
BIND_EMULATOR save/state/PPSSPP-Ext ppsspp/.config/ppsspp/PSP/PPSSPP_STATE

# muOS boot checks for this to know when storage mounts are available for use.
touch /run/muos/storage/mounted
