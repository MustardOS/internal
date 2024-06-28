#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

ASSIGN_DIR="$DC_STO_ROM_MOUNT/MUOS/info/assign/*.ini"

set -- "$ASSIGN_DIR"
if [ $# -eq 0 ]; then
	exit 1
fi

GEN_ASSIGN_DIR() {
	INI_FILE="$1"
	CORE_CATALOGUE=$(PARSE_INI "$INI_FILE" "global" "catalogue")

	if [ -z "$CORE_CATALOGUE" ]; then
		return
	fi

	BASE_DIR="$DC_STO_ROM_MOUNT/MUOS/info/catalogue/$CORE_CATALOGUE"
	mkdir -p "$BASE_DIR/box" "$BASE_DIR/preview" "$BASE_DIR/text"
}

for INI_FILE in $ASSIGN_DIR; do
	GEN_ASSIGN_DIR "$INI_FILE"
done
