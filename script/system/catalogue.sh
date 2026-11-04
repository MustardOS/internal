#!/bin/sh

. /opt/muos/script/var/base.sh
. /opt/muos/script/var/manifest.sh

if [ "${MUOS_STORAGE_LOCKED:-0}" -eq 0 ]; then
	MUOS_STORAGE_LOCKED=1 /usr/bin/flock -E 75 -w 60 "$MUOS_RUN_DIR/storage-write.lock" "$0" "$@"
	LOCK_STATUS=$?
	if [ "$LOCK_STATUS" -eq 75 ]; then
		printf '%s\n' "Catalogue generation could not acquire the storage lock" >&2
	fi
	exit "$LOCK_STATUS"
fi

BASE_PATH="$MUOS_STORE_DIR/info/catalogue"
TARGET_DIRS="box grid preview splash text manual overlay/base overlay/battery overlay/bright overlay/volume"
EXTRA_DIRS="Application Archive Collection Folder Root Task Theme"

MANIFEST_DATA=$(CORE_MANIFEST_MERGED) || {
	printf 'No core definitions found in %s\n' "$CORE_MANIFEST_DIR" >&2
	exit 1
}

CATALOGUE_NAMES=$(printf '%s' "$MANIFEST_DATA" | jq -r '[to_entries[] | .value.catalogue // .key] | unique[]') || {
	printf '%s\n' "Could not parse catalogue names from the core manifest" >&2
	exit 1
}

CREATE_DIR() {
	[ -d "$1" ] && return 0

	mkdir -p "$1" || {
		printf 'Could not create catalogue directory: %s\n' "$1" >&2
		return 1
	}
}

CREATE_TARGETS() {
	for T_DIR in $TARGET_DIRS; do
		CREATE_DIR "$BASE_PATH/$1/$T_DIR" || return 1
	done
}

while IFS= read -r C_NAME; do
	[ -n "$C_NAME" ] || continue
	CREATE_TARGETS "$C_NAME" || exit 1
done <<EOF_NAMES
$CATALOGUE_NAMES
EOF_NAMES

for EXTRA_DIR in $EXTRA_DIRS; do
	CREATE_TARGETS "$EXTRA_DIR" || exit 1
done
