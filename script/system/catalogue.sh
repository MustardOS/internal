#!/bin/sh

. /opt/muos/script/var/func.sh

BUNDLED_MANIFEST_DIR="$MUOS_SHARE_DIR/info/manifest"
USER_MANIFEST_DIR="$MUOS_STORE_DIR/info/manifest"
BASE_PATH="$MUOS_STORE_DIR/info/catalogue"
TARGET_DIRS="box grid preview text splash manual video overlay/base overlay/battery overlay/bright overlay/volume"
EXTRA_DIRS="Application Archive Collection Folder Root Task Theme"

MANIFEST_FILE=""
if [ -r "$USER_MANIFEST_DIR/core.json" ] && jq -e 'type == "object"' "$USER_MANIFEST_DIR/core.json" >/dev/null 2>&1; then
	MANIFEST_FILE="$USER_MANIFEST_DIR/core.json"
elif [ -r "$BUNDLED_MANIFEST_DIR/core.json" ] && jq -e 'type == "object"' "$BUNDLED_MANIFEST_DIR/core.json" >/dev/null 2>&1; then
	MANIFEST_FILE="$BUNDLED_MANIFEST_DIR/core.json"
fi

if [ -z "$MANIFEST_FILE" ]; then
	printf "No core definitions found in %s\n" "$BUNDLED_MANIFEST_DIR" >&2
	exit 1
fi

jq -r '[to_entries[] | .value.catalogue // .key] | unique[]' "$MANIFEST_FILE" |
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
