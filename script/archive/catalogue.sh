#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_STORE_DIR/info"
ARC_LABEL="Catalogue"

ARC_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

ARC_EXTRACT_POST() {
	printf "Updating Catalogue...\n"
	/opt/muos/script/system/catalogue.sh >/dev/null 2>&1
}

ARC_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=0
}
