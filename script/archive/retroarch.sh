#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_RUN_DIR/retroarch-archive"
ARC_LABEL="RetroArch Data"

RA_DIR="$MUOS_SHARE_DIR/emulator/retroarch"
RA_CONFIG="$MUOS_SHARE_DIR/info/config"

ARC_EXTRACT() {
	DEST="$MUOS_SHARE_DIR/emulator"
	LABEL="$ARC_LABEL"
}

ARC_EXTRACT_POST() {
	STAGED="$RA_DIR/content-config"
	[ -d "$STAGED" ] || return "$1"

	mkdir -p "$RA_CONFIG"
	cp -R "$STAGED/." "$RA_CONFIG/" || {
		rm -rf "$STAGED"
		return 1
	}
	rm -rf "$STAGED"

	return "$1"
}

ARC_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=9
}

ARC_CREATE_PRE() {
	rm -rf "$ARC_DIR"
	mkdir -p "$ARC_DIR/retroarch" || return 1

	[ -d "$RA_CONFIG" ] && ln -s "$RA_CONFIG" "$ARC_DIR/retroarch/content-config"
	for RA_PART in overlays shaders cheats; do
		[ -d "$RA_DIR/$RA_PART" ] && ln -s "$RA_DIR/$RA_PART" "$ARC_DIR/retroarch/$RA_PART"
	done

	return 0
}

ARC_CREATE_POST() {
	rm -rf "$ARC_DIR"
}
