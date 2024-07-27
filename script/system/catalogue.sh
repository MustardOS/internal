#!/bin/sh

ASSIGN_DIR="$1/MUOS/info/assign/*.ini"

set -- "$ASSIGN_DIR"
if [ $# -eq 0 ]; then
	exit 1
fi

for INI_FILE in $ASSIGN_DIR; do
	CORE_CATALOGUE=$(PARSE_INI "$INI_FILE" "global" "catalogue")
	if [ -n "$CORE_CATALOGUE" ]; then
		BASE_DIR="$1/MUOS/info/catalogue/$CORE_CATALOGUE"
		if [ ! -d "$BASE_DIR" ]; then
			mkdir -p "$BASE_DIR/box" "$BASE_DIR/preview" "$BASE_DIR/text"
		fi
	fi
done

EXTRA_DIRS="Folder Root"
for EXTRA_DIR in $EXTRA_DIRS; do
	BASE_DIR="$1/MUOS/info/catalogue/$EXTRA_DIR"
	if [ ! -d "$BASE_DIR" ]; then
		mkdir -p "$BASE_DIR/box" "$BASE_DIR/preview" "$BASE_DIR/text"
	fi
done
