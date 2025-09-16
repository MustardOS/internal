#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_SHARE_DIR/emulator/retroarch"
ARC_LABEL="RetroArch Shaders"

ARC_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

ARC_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=9
}
