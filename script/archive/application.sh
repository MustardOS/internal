#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$ROM_MOUNT/MUOS"
ARC_LABEL="Application"

MU_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

MU_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=9
}
