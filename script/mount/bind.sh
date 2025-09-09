#!/bin/sh

. /opt/muos/script/var/func.sh

PRIORITY_LOCS="bios init info/track save theme"
STANDARD_LOCS="info/catalogue info/name info/collection info/history network screenshot syncthing package/catalogue package/config"
MOUNT_FAILURE="/tmp/muos_mount_failure"

SDCARD_MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"

rm -f "$MUOS_STORE_DIR/mounted" "$MOUNT_FAILURE"
mkdir -p "$MUOS_STORE_DIR"

MOUNT_STORAGE() {
	LIST="$1"
	GROUP="$2"

	for S_LOC in $LIST; do
		TGT="$MUOS_STORE_DIR/$S_LOC"
		mkdir -p "$TGT"

		if [ -d "$SDCARD_MOUNT/MUOS/$S_LOC" ]; then
			SRC="$SDCARD_MOUNT/MUOS/$S_LOC"
			LOG_INFO "$0" 0 "BIND MOUNT" "$GROUP: $S_LOC from SDCARD"
		elif [ -d "$ROM_MOUNT/MUOS/$S_LOC" ]; then
			SRC="$ROM_MOUNT/MUOS/$S_LOC"
			LOG_INFO "$0" 0 "BIND MOUNT" "$GROUP: $S_LOC from ROM"
		else
			echo "$S_LOC" >>"$MOUNT_FAILURE"
			LOG_INFO "$0" 0 "BIND MOUNT" "$GROUP: $S_LOC not found"
			continue
		fi

		umount "$TGT"

		if mount -n --bind "$SRC" "$TGT"; then
			LOG_INFO "$0" 0 "BIND MOUNT" "Mounted $SRC -> $TGT"
		else
			LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to mount $SRC -> $TGT"
			echo "$S_LOC" >>"$MOUNT_FAILURE"
		fi &
	done
	wait
}

LOG_INFO "$0" 0 "BIND MOUNT" "Mounting PRIORITY paths"
MOUNT_STORAGE "$PRIORITY_LOCS" "PRIORITY"

[ -s "$MOUNT_FAILURE" ] && CRITICAL_FAILURE mount
touch "$MUOS_STORE_DIR/mounted"

LOG_INFO "$0" 0 "BIND MOUNT" "Mounting STANDARD paths"
MOUNT_STORAGE "$STANDARD_LOCS" "STANDARD"

[ -s "$MOUNT_FAILURE" ] && CRITICAL_FAILURE mount

# Bind hardcoded paths on SD1's ROM partition (where we can't use symlinks) to subdirs
# of the appropriate locations under /run/muos/storage ($MUOS_STORE_DIR) bound above.
BIND_EMULATOR() {
	TARGET="$MUOS_STORE_DIR/$1"
	MOUNT="$MUOS_SHARE_DIR/emulator/$2"
	mkdir -p "$TARGET" "$MOUNT"

	umount "$MOUNT"

	if mount -n --bind "$TARGET" "$MOUNT"; then
		LOG_INFO "$0" 0 "BIND MOUNT" "Bound emulator path $TARGET -> $MOUNT"
	else
		LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to bind emulator path $TARGET -> $MOUNT"
		CRITICAL_FAILURE mount
	fi
}

LOG_INFO "$0" 0 "BIND MOUNT" "Binding emulator-specific paths"

BIND_EMULATOR "save/drastic-legacy/backup" "drastic-legacy/backup" &
BIND_EMULATOR "save/drastic-legacy/savestates" "drastic-legacy/savestates" &
BIND_EMULATOR "save/file/OpenBOR-Ext" "openbor/userdata/saves/openbor" &
BIND_EMULATOR "screenshot" "openbor/userdata/screenshots/openbor" &
BIND_EMULATOR "save/pico8" "pico8/.lexaloffle/pico-8" &

PSP_DEVICE=
case "$(GET_VAR "device" "board/name")" in
	rg*) PSP_DEVICE="rg" ;;
	tui*) PSP_DEVICE="tui" ;;
esac

BIND_EMULATOR "save/game/PPSSPP-Ext" "ppsspp/${PSP_DEVICE}/.config/ppsspp/PSP/GAME" &
BIND_EMULATOR "save/file/PPSSPP-Ext" "ppsspp/${PSP_DEVICE}/.config/ppsspp/PSP/SAVEDATA" &
BIND_EMULATOR "save/state/PPSSPP-Ext" "ppsspp/${PSP_DEVICE}/.config/ppsspp/PSP/PPSSPP_STATE" &
