#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_STORE_DIR"
ARC_LABEL="Init Scripts"

ARC_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

ARC_EXTRACT_POST() {
	[ -d "$ARC_DIR/init" ] || return 0
	printf "Moving init scripts to hook/startup...\n"
	mkdir -p "$ARC_DIR/hook/startup"
	find "$ARC_DIR/init" -mindepth 1 -maxdepth 1 -exec mv -f {} "$ARC_DIR/hook/startup/" \;
	rmdir "$ARC_DIR/init" 2>/dev/null || :
}
