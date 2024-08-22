#!/bin/sh

if [ $# -ne 1 ]; then
	echo "Usage: $0 <mount>"
	exit 1
fi

. /opt/muos/script/var/func.sh

ASSIGN_DIR="$1/MUOS/info/assign/*.ini"
set -- "$ASSIGN_DIR"
for INI_FILE in $ASSIGN_DIR; do
	CORE_CATALOGUE=$(PARSE_INI "$INI_FILE" "global" "catalogue")
	if [ -n "$CORE_CATALOGUE" ]; then
		BASE_DIR="/run/muos/storage/catalogue/$CORE_CATALOGUE"
		if [ ! -d "$BASE_DIR" ]; then
			mkdir -p "$BASE_DIR/box" "$BASE_DIR/preview" "$BASE_DIR/text"
		fi
	fi
done

EXTRA_DIRS="Folder Root"
for EXTRA_DIR in $EXTRA_DIRS; do
	BASE_DIR="/run/muos/storage/catalogue/$EXTRA_DIR"
	if [ ! -d "$BASE_DIR" ]; then
		mkdir -p "$BASE_DIR/box" "$BASE_DIR/preview" "$BASE_DIR/text"
	fi
done
