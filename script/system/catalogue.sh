#!/bin/sh

. /opt/muos/script/var/func.sh

CORE_DIR="$MUOS_SHARE_DIR/info/core"
USER_CORE_DIR="$MUOS_STORE_DIR/info/core"
BASE_PATH="$MUOS_STORE_DIR/info/catalogue"
TARGET_DIRS="box grid preview text splash manual video overlay/base overlay/battery overlay/bright overlay/volume"
EXTRA_DIRS="Application Archive Collection Folder Root Task Theme"

CORE_FILES=""
for C_FILE in libretro external; do
	if [ -r "$USER_CORE_DIR/$C_FILE.json" ] && jq -e 'type == "object"' "$USER_CORE_DIR/$C_FILE.json" >/dev/null 2>&1; then
		CORE_FILES="$CORE_FILES $USER_CORE_DIR/$C_FILE.json"
	elif [ -r "$CORE_DIR/$C_FILE.json" ] && jq -e 'type == "object"' "$CORE_DIR/$C_FILE.json" >/dev/null 2>&1; then
		CORE_FILES="$CORE_FILES $CORE_DIR/$C_FILE.json"
	fi
done

if [ -z "$CORE_FILES" ]; then
	printf "No core definitions found in %s\n" "$CORE_DIR" >&2
	exit 1
fi

# shellcheck disable=SC2086
jq -r -s '[.[] | to_entries[] | .value.catalogue // .key] | unique[]' $CORE_FILES |
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
