#!/bin/sh

. /opt/muos/script/var/func.sh

ASSIGN_DIR="$MUOS_SHARE_DIR/info/assign"
BASE_PATH="$MUOS_STORE_DIR/info/catalogue"
TARGET_DIRS="box grid preview text splash overlay/base overlay/battery overlay/bright overlay/volume"
EXTRA_DIRS="Application Archive Collection Folder Root Task Theme"

# Create core catalogue directories from assign directories only
for A_DIR in "$ASSIGN_DIR"/*; do
	[ -d "$A_DIR" ] || continue
	C_NAME=$(basename "$A_DIR")
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
