#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="/opt/muos"
ARC_LABEL="Internal Scripts"

MU_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

MU_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=0
}
