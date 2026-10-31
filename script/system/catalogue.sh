#!/bin/sh

. /opt/muos/script/var/base.sh
. /opt/muos/script/var/manifest.sh

BASE_PATH="$MUOS_STORE_DIR/info/catalogue"
TARGET_DIRS="box grid preview splash text manual overlay/base overlay/battery overlay/bright overlay/volume"
EXTRA_DIRS="Application Archive Collection Folder Root Task Theme"

MANIFEST_DATA=$(CORE_MANIFEST_MERGED) || {
	printf "No core definitions found in %s\n" "$CORE_MANIFEST_DIR" >&2
	exit 1
}

printf '%s' "$MANIFEST_DATA" | jq -r '[to_entries[] | .value.catalogue // .key] | unique[]' |
	while IFS= read -r C_NAME; do
		[ -n "$C_NAME" ] || continue
		for T_DIR in $TARGET_DIRS; do
			mkdir -p "$BASE_PATH/$C_NAME/$T_DIR"
		done
	done

# Create additional directories specified in EXTRA_DIRS
for EXTRA_DIR in $EXTRA_DIRS; do
	for DIR in $TARGET_DIRS; do
		mkdir -p "$BASE_PATH/$EXTRA_DIR/$DIR"
	done
done
