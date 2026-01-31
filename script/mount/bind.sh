#!/bin/sh

. /opt/muos/script/var/func.sh

PRIORITY_LOCS="application bios init info/track music save theme"
STANDARD_LOCS="info/catalogue info/name info/collection info/history network screenshot syncthing package/catalogue package/config"

MOUNT_FAILURE="/tmp/muos/mount_failure"

SDCARD_MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"

BINDMAP="$MUOS_STORE_DIR/bindmap"

rm -f "$MUOS_STORE_DIR/mount_ready" "$MOUNT_FAILURE"
mkdir -p "$MUOS_STORE_DIR"
: >"$BINDMAP"

IS_MOUNTED() {
	grep -q " $1 " /proc/self/mountinfo 2>/dev/null
}

SDCARD_MOUNTED=0
if [ -n "$SDCARD_MOUNT" ] && IS_MOUNTED "$SDCARD_MOUNT"; then
	SDCARD_MOUNTED=1
	LOG_INFO "$0" 0 "BIND MOUNT" "SD2 mounted at $SDCARD_MOUNT"
else
	LOG_INFO "$0" 0 "BIND MOUNT" "SD2 not mounted, skipping SD2 paths"
fi

SD_ROOT="$SDCARD_MOUNT/MUOS"
ROM_ROOT="$ROM_MOUNT/MUOS"

MAX_JOBS="${MAX_JOBS:-8}"
JOBS_COUNT=0

WAIT_JOBS() {
	wait
	JOBS_COUNT=0
}

SPAWN_JOB() {
	"$@" &
	JOBS_COUNT=$((JOBS_COUNT + 1))
	if [ "$JOBS_COUNT" -ge "$MAX_JOBS" ]; then
		wait
		JOBS_COUNT=0
	fi
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

KEYS=""

HAVE_KEY() {
	case " $KEYS " in
		*" $1 "*) return 0 ;;
	esac
	return 1
}

ADD_KEY() {
	KEYS="$KEYS $1"
}

WRITE_BINDMAP() {
	KEY="$1"
	BACKEND="$2"
	SRC="$3"

	HAVE_KEY "$KEY" && return 0
	ADD_KEY "$KEY"
	printf '%s|%s|%s\n' "$KEY" "$BACKEND" "$SRC" >>"$BINDMAP"
}

SAFE_BIND() {
	SRC="$1"
	TGT="$2"

	mkdir -p "$TGT"

	if IS_MOUNTED "$TGT"; then
		umount "$TGT" 2>/dev/null || return 1
	fi

	mount -n --bind "$SRC" "$TGT"
}

ENSURE_ROM_PATH() {
	ROM_SRC="$ROM_ROOT/$1"
	[ -d "$ROM_SRC" ] && return 0

	LOG_INFO "$0" 0 "BIND MOUNT" "Creating missing SD1 path: MUOS/$1"
	if ! mkdir -p "$ROM_SRC"; then
		LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to create SD1 path: MUOS/$1"
		echo "$1" >>"$MOUNT_FAILURE"
		return 1
	fi

	return 0
}

SELECT_SOURCE() {
	S_LOC="$1"

	if [ "$SDCARD_MOUNTED" -eq 1 ] && [ -d "$SD_ROOT/$S_LOC" ]; then
		echo "SDCARD|$SD_ROOT/$S_LOC"
		return 0
	fi

	if [ -d "$ROM_ROOT/$S_LOC" ]; then
		echo "ROM|$ROM_ROOT/$S_LOC"
		return 0
	fi

	if ENSURE_ROM_PATH "$S_LOC"; then
		echo "ROM|$ROM_ROOT/$S_LOC"
		return 0
	fi

	return 1
}

MOUNT_ONE() {
	S_LOC="$1"
	GROUP="$2"

	KEY="$(LOCS_KEY "$S_LOC")"
	TGT="$MUOS_STORE_DIR/$S_LOC"

	SEL="$(SELECT_SOURCE "$S_LOC")" || return 0
	BACKEND="${SEL%%|*}"
	SRC="${SEL#*|}"

	LOG_INFO "$0" 0 "BIND MOUNT" "$GROUP: $S_LOC from $BACKEND"

	if SAFE_BIND "$SRC" "$TGT"; then
		WRITE_BINDMAP "$KEY" "$BACKEND" "$SRC"
	else
		LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to mount $SRC -> $TGT"
		echo "$S_LOC" >>"$MOUNT_FAILURE"
	fi
}

MOUNT_STORAGE() {
	LIST="$1"
	GROUP="$2"

	for S_LOC in $LIST; do
		SPAWN_JOB MOUNT_ONE "$S_LOC" "$GROUP"
	done

	WAIT_JOBS
}

FAIL_IF_ANY() {
	[ -s "$MOUNT_FAILURE" ] && CRITICAL_FAILURE mount "$(cat "$MOUNT_FAILURE")"
}

LOG_INFO "$0" 0 "BIND MOUNT" "Mounting PRIORITY paths"
MOUNT_STORAGE "$PRIORITY_LOCS" "PRIORITY"

FAIL_IF_ANY
: >"$MUOS_STORE_DIR/mount_ready"

LOG_INFO "$0" 0 "BIND MOUNT" "Mounting STANDARD paths"
MOUNT_STORAGE "$STANDARD_LOCS" "STANDARD"

FAIL_IF_ANY

BIND_EMULATOR() {
	STORE_PATH="$1"
	EMU_PATH="$2"

	TARGET="$MUOS_STORE_DIR/$STORE_PATH"
	MOUNT="$MUOS_SHARE_DIR/emulator/$EMU_PATH"

	mkdir -p "$TARGET" "$MOUNT"

	if SAFE_BIND "$TARGET" "$MOUNT"; then
		LOG_INFO "$0" 0 "BIND MOUNT" "Bound emulator path $TARGET -> $MOUNT"
	else
		LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to bind emulator path $TARGET -> $MOUNT"
		echo "$STORE_PATH" >>"$MOUNT_FAILURE"
	fi
}

# Bind hardcoded paths of the appropriate locations under /run/muos/storage ($MUOS_STORE_DIR) bound above.
LOG_INFO "$0" 0 "BIND MOUNT" "Binding emulator-specific paths"

DL_DIR="drastic-legacy"
OB_DIR="openbor/userdata"
PS_DIR="ppsspp/.config/ppsspp"

EMU_BINDS="
save/pico8|pico8/.lexaloffle/pico-8
save/$DL_DIR/backup|$DL_DIR/backup
save/$DL_DIR/savestates|$DL_DIR/savestates
save/file/OpenBOR-Ext|$OB_DIR/saves/openbor
screenshot|$OB_DIR/screenshots/openbor
save/game/PPSSPP-Ext|$PS_DIR/PSP/GAME
save/file/PPSSPP-Ext|$PS_DIR/PSP/SAVEDATA
save/state/PPSSPP-Ext|$PS_DIR/PSP/PPSSPP_STATE
"

IFS='
'
for LINE in $EMU_BINDS; do
	[ -n "$LINE" ] || continue

	STORE_PATH="${LINE%%|*}"
	EMU_PATH="${LINE#*|}"

	[ -n "$STORE_PATH" ] || continue
	SPAWN_JOB BIND_EMULATOR "$STORE_PATH" "$EMU_PATH"
done
unset IFS

WAIT_JOBS
FAIL_IF_ANY

RA_DIR="$MUOS_SHARE_DIR/emulator/retroarch"

ADD_INTERNAL() {
	KEY="$1"
	BACKEND="$2"
	SRC="$3"

	HAVE_KEY "$KEY" && return 0
	ADD_KEY "$KEY"
	printf '%s|%s|%s\n' "$KEY" "$BACKEND" "$SRC" >>"$BINDMAP"
}

ADD_INTERNAL "archive"   "ROM"      "$ROM_MOUNT/ARCHIVE"
ADD_INTERNAL "assign"    "INTERNAL" "$MUOS_SHARE_DIR/info/assign"
ADD_INTERNAL "cheats"    "INTERNAL" "$RA_DIR/cheats"
ADD_INTERNAL "config"    "INTERNAL" "$MUOS_SHARE_DIR/info/config"
ADD_INTERNAL "core"      "INTERNAL" "$MUOS_SHARE_DIR/core"
ADD_INTERNAL "emulator"  "INTERNAL" "$MUOS_SHARE_DIR/emulator"
ADD_INTERNAL "hotkey"    "INTERNAL" "$MUOS_SHARE_DIR/hotkey"
ADD_INTERNAL "info"      "INTERNAL" "$MUOS_SHARE_DIR/info"
ADD_INTERNAL "language"  "INTERNAL" "$MUOS_SHARE_DIR/language"
ADD_INTERNAL "overlays"  "INTERNAL" "$RA_DIR/overlays"
ADD_INTERNAL "override"  "INTERNAL" "$MUOS_SHARE_DIR/info/override"
ADD_INTERNAL "script"    "INTERNAL" "/opt/muos/script"
ADD_INTERNAL "shaders"   "INTERNAL" "$RA_DIR/shaders"
ADD_INTERNAL "task"      "INTERNAL" "$MUOS_SHARE_DIR/task"

LC_ALL=C awk -F'|' -v OFS='|' '$1 == "package" { sub(/\/package\/.*/, "/package", $3) } { print }' \
	"$BINDMAP" | LC_ALL=C sort -t'|' -k1,1 >"$BINDMAP.tmp" && mv "$BINDMAP.tmp" "$BINDMAP"
