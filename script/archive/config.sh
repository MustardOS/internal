#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_SHARE_DIR/info"
ARC_LABEL="RetroArch Configurations"

MU_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

MU_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=9
}
