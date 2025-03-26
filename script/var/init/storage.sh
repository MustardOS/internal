#!/bin/sh

. /opt/muos/script/var/func.sh

PRIORITY_LOCS="bios init retroarch music save theme language"
STANDARD_LOCS="info/catalogue info/name info/config info/controller info/core info/collection info/history screenshot network syncthing package/catalogue package/config"
STORAGE_RUN="/run/muos/storage"
MOUNT_FAILURE="/tmp/muos_mount_failure"

SDCARD_MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"

rm -f "$STORAGE_RUN/mounted" "$MOUNT_FAILURE"
mkdir -p "$STORAGE_RUN"

PRIORITY_MOUNT_LIST=""
for S_LOC in $PRIORITY_LOCS; do
	mkdir -p "$STORAGE_RUN/$S_LOC"

	if [ -d "$SDCARD_MOUNT/MUOS/$S_LOC" ]; then
		SRC="$SDCARD_MOUNT/MUOS/$S_LOC"
	elif [ -d "$ROM_MOUNT/MUOS/$S_LOC" ]; then
		SRC="$ROM_MOUNT/MUOS/$S_LOC"
	else
		echo "$S_LOC" >>"$MOUNT_FAILURE"
		continue
	fi

	TGT="$STORAGE_RUN/$S_LOC"
	PRIORITY_MOUNT_LIST="${PRIORITY_MOUNT_LIST}${SRC} ${TGT}
"
done

printf "%s" "$PRIORITY_MOUNT_LIST" | while IFS= read -r LINE; do
	[ -z "$LINE" ] && continue
	SRC=$(printf "%s\n" "$LINE" | awk '{print $1}')
	TGT=$(printf "%s\n" "$LINE" | awk '{print $2}')
	mount -n --bind "$SRC" "$TGT" &
done
wait

[ -s "$MOUNT_FAILURE" ] && CRITICAL_FAILURE mount
touch "$STORAGE_RUN/mounted"

STANDARD_MOUNT_LIST=""
for S_LOC in $STANDARD_LOCS; do
	mkdir -p "$STORAGE_RUN/$S_LOC"

	if [ -d "$SDCARD_MOUNT/MUOS/$S_LOC" ]; then
		SRC="$SDCARD_MOUNT/MUOS/$S_LOC"
	elif [ -d "$ROM_MOUNT/MUOS/$S_LOC" ]; then
		SRC="$ROM_MOUNT/MUOS/$S_LOC"
	else
		echo "$S_LOC" >>"$MOUNT_FAILURE"
		continue
	fi

	TGT="$STORAGE_RUN/$S_LOC"
	STANDARD_MOUNT_LIST="${STANDARD_MOUNT_LIST}${SRC} ${TGT}
"
done

printf "%s" "$STANDARD_MOUNT_LIST" | while IFS= read -r LINE; do
	[ -z "$LINE" ] && continue
	SRC=$(printf "%s\n" "$LINE" | awk '{print $1}')
	TGT=$(printf "%s\n" "$LINE" | awk '{print $2}')
	mount -n --bind "$SRC" "$TGT" &
done
wait

[ -s "$MOUNT_FAILURE" ] && CRITICAL_FAILURE mount

# Bind hardcoded paths on SD1's ROM partition (where we can't use symlinks) to
# subdirs of the appropriate locations under /run/muos/storage (bound above).
BIND_EMULATOR() {
	TARGET="$STORAGE_RUN/$1"
	MOUNT="$ROM_MOUNT/MUOS/emulator/$2"
	mkdir -p "$TARGET" "$MOUNT"
	mount -n --bind "$TARGET" "$MOUNT" || CRITICAL_FAILURE mount
}

# Drastic Legacy
BIND_EMULATOR "save/drastic-legacy/backup" "drastic-legacy/backup" &
BIND_EMULATOR "save/drastic-legacy/savestates" "drastic-legacy/savestates" &

# OpenBOR
BIND_EMULATOR "save/file/OpenBOR-Ext" "openbor/userdata/saves/openbor" &
BIND_EMULATOR "screenshot" "openbor/userdata/screenshots/openbor" &

# PICO-8
BIND_EMULATOR "save/pico8" "pico8/.lexaloffle/pico-8" &

# PPSSPP
BIND_EMULATOR "save/file/PPSSPP-Ext" "ppsspp/.config/ppsspp/PSP/SAVEDATA" &
BIND_EMULATOR "save/state/PPSSPP-Ext" "ppsspp/.config/ppsspp/PSP/PPSSPP_STATE" &
