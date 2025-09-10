#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_STORE_DIR/info"
ARC_LABEL="Playtime Data"

MU_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

MU_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=0
}
