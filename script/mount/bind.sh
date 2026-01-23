#!/bin/sh

. /opt/muos/script/var/func.sh

PRIORITY_LOCS="application bios init info/track music save theme"
STANDARD_LOCS="info/catalogue info/name info/collection info/history network screenshot syncthing package/catalogue package/config"

MOUNT_FAILURE="/tmp/muos/mount_failure"

SDCARD_MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"

rm -f "$MUOS_STORE_DIR/mounted" "$MOUNT_FAILURE"
mkdir -p "$MUOS_STORE_DIR"

SDCARD_MOUNTED=0
if [ -n "$SDCARD_MOUNT" ] && mount | grep -q " on $SDCARD_MOUNT "; then
	SDCARD_MOUNTED=1
	LOG_INFO "$0" 0 "BIND MOUNT" "SD2 mounted at $SDCARD_MOUNT"
else
	LOG_INFO "$0" 0 "BIND MOUNT" "SD2 not mounted, skipping SD2 paths"
fi

BINDMAP="$MUOS_STORE_DIR/bindmap"
: >"$BINDMAP"

FIX_PACKAGE_ROOT() {
	awk -F'|' -v OFS='|' '$1 == "package" { sub(/\/package\/.*/, "/package", $3) } { print }' "$BINDMAP" >"$BINDMAP.tmp"
	mv "$BINDMAP.tmp" "$BINDMAP"
}

LOCS_KEY() {
	case "$1" in
		info/catalogue*) echo "catalogue" ;;
		info/name*) echo "name" ;;
		info/collection*) echo "collection" ;;
		info/history*) echo "history" ;;
		info/track*) echo "track" ;;
		package/*) echo "package" ;;
		*) echo "$1" ;;
	esac
}

WRITE_BINDMAP() {
	KEY="$1" # archive top-level folder name
	BACKEND="$2" # SDCARD / ROM / INTERNAL (we do internal later down below)
	SRC="$3" # the actual mounted path

	# Skip if key already exists
	if awk -F'|' -v k="$KEY" '$1 == k { found=1 } END { exit !found }' "$BINDMAP"; then
		return 0
	fi

	printf '%s|%s|%s\n' "$KEY" "$BACKEND" "$SRC" >>"$BINDMAP"
}

SORT_BINDMAP() {
	LC_ALL=C sort -t '|' -k1,1 "$BINDMAP" -o "$BINDMAP"
}

SAFE_BIND() {
	SRC="$1"
	TGT="$2"

	mkdir -p "$TGT"
	umount "$TGT" 2>/dev/null

	mount -n --bind "$SRC" "$TGT"
}

ENSURE_ROM_PATH() {
	S_LOC="$1"
	ROM_SRC="$ROM_MOUNT/MUOS/$S_LOC"

	if [ ! -d "$ROM_SRC" ]; then
		LOG_INFO "$0" 0 "BIND MOUNT" "Creating missing SD1 path: MUOS/$S_LOC"
		if ! mkdir -p "$ROM_SRC"; then
			LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to create SD1 path: MUOS/$S_LOC"
			echo "$S_LOC" >>"$MOUNT_FAILURE"
			return 1
		fi
	fi

	return 0
}

MOUNT_STORAGE() {
	LIST="$1"
	GROUP="$2"

	for S_LOC in $LIST; do
		TGT="$MUOS_STORE_DIR/$S_LOC"
		SRC=""
		KEY="$(LOCS_KEY "$S_LOC")"

		if [ "$SDCARD_MOUNTED" -eq 1 ] && [ -d "$SDCARD_MOUNT/MUOS/$S_LOC" ]; then
			SRC="$SDCARD_MOUNT/MUOS/$S_LOC"
			BACKEND="SDCARD"
			LOG_INFO "$0" 0 "BIND MOUNT" "$GROUP: $S_LOC from SDCARD"
		elif [ -d "$ROM_MOUNT/MUOS/$S_LOC" ]; then
			SRC="$ROM_MOUNT/MUOS/$S_LOC"
			BACKEND="ROM"
			LOG_INFO "$0" 0 "BIND MOUNT" "$GROUP: $S_LOC from ROM"
		else
			LOG_INFO "$0" 0 "BIND MOUNT" "$GROUP: $S_LOC missing, recreating on ROM"

			if ! ENSURE_ROM_PATH "$S_LOC"; then
				continue
			fi

			SRC="$ROM_MOUNT/MUOS/$S_LOC"
			BACKEND="ROM"
		fi

		if SAFE_BIND "$SRC" "$TGT"; then
			LOG_INFO "$0" 0 "BIND MOUNT" "Mounted $SRC -> $TGT"
			WRITE_BINDMAP "$KEY" "$BACKEND" "$SRC"
		else
			LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to mount $SRC -> $TGT"
			echo "$S_LOC" >>"$MOUNT_FAILURE"
		fi
	done
}

LOG_INFO "$0" 0 "BIND MOUNT" "Mounting PRIORITY paths"
MOUNT_STORAGE "$PRIORITY_LOCS" "PRIORITY"

[ -s "$MOUNT_FAILURE" ] && CRITICAL_FAILURE mount "$(cat "$MOUNT_FAILURE")"
: >"$MUOS_STORE_DIR/mounted"

LOG_INFO "$0" 0 "BIND MOUNT" "Mounting STANDARD paths"
MOUNT_STORAGE "$STANDARD_LOCS" "STANDARD"

[ -s "$MOUNT_FAILURE" ] && CRITICAL_FAILURE mount "$(cat "$MOUNT_FAILURE")"

# Bind hardcoded paths of the appropriate locations under /run/muos/storage ($MUOS_STORE_DIR) bound above.
BIND_EMULATOR() {
	STORE_PATH="$1"
	EMU_PATH="$2"

	TARGET="$MUOS_STORE_DIR/$STORE_PATH"
	MOUNT="$MUOS_SHARE_DIR/emulator/$EMU_PATH"

	mkdir -p "$TARGET" "$MOUNT"
	umount "$MOUNT" 2>/dev/null

	if SAFE_BIND "$TARGET" "$MOUNT"; then
		LOG_INFO "$0" 0 "BIND MOUNT" "Bound emulator path $TARGET -> $MOUNT"
	else
		LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to bind emulator path $TARGET -> $MOUNT"
		CRITICAL_FAILURE mount "$MOUNT"
	fi
}

LOG_INFO "$0" 0 "BIND MOUNT" "Binding emulator-specific paths"
BIND_EMULATOR "save/pico8" "pico8/.lexaloffle/pico-8"

DL_DIR="drastic-legacy"
BIND_EMULATOR "save/$DL_DIR/backup" "$DL_DIR/backup"
BIND_EMULATOR "save/$DL_DIR/savestates" "$DL_DIR/savestates"

OB_DIR="openbor/userdata"
BIND_EMULATOR "save/file/OpenBOR-Ext" "$OB_DIR/saves/openbor"
BIND_EMULATOR "screenshot" "$OB_DIR/screenshots/openbor"

PS_DIR="ppsspp/.config/ppsspp"
BIND_EMULATOR "save/game/PPSSPP-Ext" "$PS_DIR/PSP/GAME"
BIND_EMULATOR "save/file/PPSSPP-Ext" "$PS_DIR/PSP/SAVEDATA"
BIND_EMULATOR "save/state/PPSSPP-Ext" "$PS_DIR/PSP/PPSSPP_STATE"

RA_DIR="$MUOS_SHARE_DIR/emulator/retroarch"

INTERNAL_ENTRIES="
archive|ROM|$ROM_MOUNT/ARCHIVE
assign|INTERNAL|$MUOS_SHARE_DIR/info/assign
cheats|INTERNAL|$RA_DIR/cheats
config|INTERNAL|$MUOS_SHARE_DIR/info/config
core|INTERNAL|$MUOS_SHARE_DIR/core
emulator|INTERNAL|$MUOS_SHARE_DIR/emulator
hotkey|INTERNAL|$MUOS_SHARE_DIR/hotkey
info|INTERNAL|$MUOS_SHARE_DIR/info
language|INTERNAL|$MUOS_SHARE_DIR/language
overlays|INTERNAL|$RA_DIR/overlays
override|INTERNAL|$MUOS_SHARE_DIR/info/override
script|INTERNAL|/opt/muos/script
shaders|INTERNAL|$RA_DIR/shaders
task|INTERNAL|$MUOS_SHARE_DIR/task
"

ADD_INTERNAL_ENTRIES() {
	printf '%s\n' "$INTERNAL_ENTRIES" | while IFS='|' read -r KEY BACKEND SRC; do
		[ -n "$KEY" ] || continue

		# Skip if key already exists
		if awk -F'|' -v k="$KEY" '$1 == k { found=1 } END { exit !found }' "$BINDMAP"; then
			continue
		fi

		printf '%s|%s|%s\n' "$KEY" "$BACKEND" "$SRC" >>"$BINDMAP"
	done
}

ADD_INTERNAL_ENTRIES
FIX_PACKAGE_ROOT
SORT_BINDMAP
