#!/bin/sh

. /opt/muos/script/var/log.sh
. /opt/muos/script/var/manifest.sh

PRIORITY_LOCS="application bios init info/manifest info/track music pickles save theme wasabi"
STANDARD_LOCS="info/catalogue info/name info/launch info/collection info/history info/override network profile screenshot syncthing package/catalogue package/config"

MOUNT_FAILURE="/tmp/muos/mount_failure"

SDCARD_MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"

BINDMAP="$MUOS_STORE_DIR/bindmap"

LOCK_RUN storage-bind "$@" || exit "$LOCK_STATUS"

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

IS_MOUNTED() {
	findmnt -rn -M "$1" >/dev/null 2>&1
}

SAME_BIND() {
	BIND_SRC="$1"
	BIND_TGT="$2"

	SRC_INFO=$(findmnt -rn -T "$BIND_SRC" -o MAJ:MIN,TARGET,FSROOT 2>/dev/null) || return 1
	SRC_DEVICE=
	SRC_MOUNT=
	SRC_ROOT=
	SRC_EXTRA=
	read -r SRC_DEVICE SRC_MOUNT SRC_ROOT SRC_EXTRA <<EOF
$SRC_INFO
EOF
	[ -n "$SRC_DEVICE" ] && [ -n "$SRC_MOUNT" ] && [ -n "$SRC_ROOT" ] && [ -z "$SRC_EXTRA" ] || return 1

	TGT_INFO=$(findmnt -rn -M "$BIND_TGT" -o MAJ:MIN,FSROOT 2>/dev/null) || return 1
	case "$TGT_INFO" in *"
"*) return 1 ;; esac
	TGT_DEVICE=
	TGT_ROOT=
	TGT_EXTRA=
	read -r TGT_DEVICE TGT_ROOT TGT_EXTRA <<EOF
$TGT_INFO
EOF
	[ -n "$TGT_DEVICE" ] && [ -n "$TGT_ROOT" ] && [ -z "$TGT_EXTRA" ] || return 1

	SRC_RELATIVE=${BIND_SRC#"$SRC_MOUNT"}
	[ "$SRC_RELATIVE" != "$BIND_SRC" ] || return 1
	case "$SRC_RELATIVE" in
		"") ;;
		/*) ;;
		*) SRC_RELATIVE="/$SRC_RELATIVE" ;;
	esac

	case "$SRC_ROOT" in
		/) EXPECTED_ROOT="${SRC_RELATIVE:-/}" ;;
		*) EXPECTED_ROOT="${SRC_ROOT%/}$SRC_RELATIVE" ;;
	esac

	[ "$SRC_DEVICE" = "$TGT_DEVICE" ] && [ "$EXPECTED_ROOT" = "$TGT_ROOT" ]
}

UNMOUNT_BIND() {
	BIND_TARGET="$1"
	IS_MOUNTED "$BIND_TARGET" || return 0

	UNMOUNT_COUNT=0
	while IS_MOUNTED "$BIND_TARGET"; do
		if ! umount "$BIND_TARGET" 2>/dev/null; then
			LOG_ERROR "$0" 0 "BIND MOUNT" "Could not unmount $BIND_TARGET"
			return 1
		fi

		UNMOUNT_COUNT=$((UNMOUNT_COUNT + 1))
		if [ "$UNMOUNT_COUNT" -ge 8 ] && IS_MOUNTED "$BIND_TARGET"; then
			LOG_ERROR "$0" 0 "BIND MOUNT" "Too many stacked mounts at $BIND_TARGET"
			return 1
		fi
	done

	LOG_INFO "$0" 0 "BIND MOUNT" "Unmounted $BIND_TARGET"
	return 0
}

UNMOUNT_BINDINGS() {
	UNMOUNT_STATUS=0

	# Emulator mounts depend on storage bind mounts, so remove them first.
	OLD_IFS=$IFS
	IFS='
'
	for LINE in $EMU_BINDS; do
		[ -n "$LINE" ] || continue
		EMU_PATH="${LINE#*|}"
		UNMOUNT_BIND "$MUOS_SHARE_DIR/emulator/$EMU_PATH" || UNMOUNT_STATUS=1
	done
	IFS=$OLD_IFS

	for S_LOC in $STANDARD_LOCS $PRIORITY_LOCS; do
		UNMOUNT_BIND "$MUOS_STORE_DIR/$S_LOC" || UNMOUNT_STATUS=1
	done

	rm -f "$MUOS_STORE_DIR/mount_ready"
	return "$UNMOUNT_STATUS"
}

case "${1:-mount}" in
	down)
		UNMOUNT_BINDINGS
		exit $?
		;;
	mount | up) ;;
	*)
		printf 'Usage: %s {mount|up|down}\n' "$0" >&2
		exit 2
		;;
esac

rm -f "$MUOS_STORE_DIR/mount_ready" "$MOUNT_FAILURE"
mkdir -p "$MUOS_STORE_DIR" || exit 1
: >"$BINDMAP"

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
		info/launch*) echo "launch" ;;
		info/manifest*) echo "manifest" ;;
		info/collection*) echo "collection" ;;
		info/history*) echo "history" ;;
		info/track*) echo "track" ;;
		package/*) echo "package" ;;
		*) echo "$1" ;;
	esac
}

HAVE_KEY() {
	while IFS='|' read -r MAP_KEY _; do
		[ "$MAP_KEY" = "$1" ] && return 0
	done <"$BINDMAP"
	return 1
}

WRITE_BINDMAP() {
	KEY="$1"
	BACKEND="$2"
	SRC="$3"

	HAVE_KEY "$KEY" && return 0
	printf '%s|%s|%s\n' "$KEY" "$BACKEND" "$SRC" >>"$BINDMAP"
}

SAFE_BIND() {
	SRC="$1"
	TGT="$2"

	mkdir -p "$TGT" || return 1

	if IS_MOUNTED "$TGT"; then
		SAME_BIND "$SRC" "$TGT" && return 0
		UNMOUNT_BIND "$TGT" || return 1
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

for CM_OLD in "$MUOS_STORE_DIR/info/manifest/core.json" "$CORE_MANIFEST_USER"/*.json; do
	[ -f "$CM_OLD" ] || continue
	LOG_INFO "$0" 0 "BIND MOUNT" "Moving older core definitions into namespace folders"
	CORE_MANIFEST_MIGRATE
	break
done

ASSIGN_FILE="$MUOS_STORE_DIR/info/manifest/assign.json"
if [ ! -s "$ASSIGN_FILE" ]; then
	LOG_INFO "$0" 0 "BIND MOUNT" "Generating missing core assignments"
	if ! /opt/muos/script/system/assign.sh -p; then
		LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to generate core assignments"
		printf '%s\n' "info/manifest" >>"$MOUNT_FAILURE"
	fi
fi

FAIL_IF_ANY

LOG_INFO "$0" 0 "BIND MOUNT" "Mounting STANDARD paths"
MOUNT_STORAGE "$STANDARD_LOCS" "STANDARD"

FAIL_IF_ANY

BIND_EMULATOR() {
	STORE_PATH="$1"
	EMU_PATH="$2"

	TARGET="$MUOS_STORE_DIR/$STORE_PATH"
	MOUNT="$MUOS_SHARE_DIR/emulator/$EMU_PATH"

	if ! mkdir -p "$TARGET" "$MOUNT"; then
		LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to prepare emulator path $TARGET -> $MOUNT"
		echo "$STORE_PATH" >>"$MOUNT_FAILURE"
		return 1
	fi

	if SAFE_BIND "$TARGET" "$MOUNT"; then
		LOG_INFO "$0" 0 "BIND MOUNT" "Bound emulator path $TARGET -> $MOUNT"
	else
		LOG_INFO "$0" 0 "BIND MOUNT" "FAILED to bind emulator path $TARGET -> $MOUNT"
		echo "$STORE_PATH" >>"$MOUNT_FAILURE"
	fi
}

# Bind hardcoded paths of the appropriate locations under /run/muos/storage ($MUOS_STORE_DIR) bound above.
LOG_INFO "$0" 0 "BIND MOUNT" "Binding emulator-specific paths"

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
	printf '%s|%s|%s\n' "$KEY" "$BACKEND" "$SRC" >>"$BINDMAP"
}

ADD_INTERNAL "archive"   "ROM"      "$ROM_MOUNT/ARCHIVE"
ADD_INTERNAL "manifest"  "INTERNAL" "$MUOS_SHARE_DIR/info/manifest"
ADD_INTERNAL "cheats"    "INTERNAL" "$RA_DIR/cheats"
ADD_INTERNAL "config"    "INTERNAL" "$MUOS_SHARE_DIR/info/config"
ADD_INTERNAL "content"   "INTERNAL" "$MUOS_SHARE_DIR/info/content"
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

: >"$MUOS_STORE_DIR/mount_ready"

USER_INIT="$(GET_VAR "config" "settings/advanced/user_init")"
if [ "${USER_INIT:-0}" -eq 1 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Starting User Initialisation Scripts"
	/opt/muos/script/system/user_init.sh &
fi
