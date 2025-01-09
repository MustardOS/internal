#!/bin/sh

if [ $# -ne 1 ]; then
	echo "Usage: $0 <mount>"
	exit 1
fi

. /opt/muos/script/var/func.sh

ASSIGN_DIR="$1/MUOS/info/assign/*.ini"
BASE_PATH="/run/muos/storage/info/catalogue"
TARGET_DIRS="box grid preview text splash"
EXTRA_DIRS="Application Archive Collection Folder Root Task"

# Create core catalogue directories from assign INI files
for INI_FILE in $ASSIGN_DIR; do
	for DIR in $TARGET_DIRS; do
		mkdir -p "$BASE_PATH/$(PARSE_INI "$INI_FILE" "global" "catalogue")/$DIR"
	done
done

# Create additional directories specified in EXTRA_DIRS
for EXTRA_DIR in $EXTRA_DIRS; do
	for DIR in $TARGET_DIRS; do
		mkdir -p "$BASE_PATH/$EXTRA_DIR/$DIR"
	done
done
