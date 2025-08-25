#!/bin/sh

. /opt/muos/script/var/func.sh

if [ $# -ne 1 ]; then
	echo "Usage: $0 <mount>"
	exit 1
fi

ASSIGN_DIR="$1/MUOS/info/assign"
BASE_PATH="/run/muos/storage/info/catalogue"
TARGET_DIRS="box grid preview text splash"
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
