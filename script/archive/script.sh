#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="/opt/muos"
ARC_LABEL="Internal Scripts"

ARC_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

ARC_EXTRACT_POST() {
	printf "Marking scripts as executable...\n"
	chmod -R 755 "$ARC_DIR" >/dev/null 2>&1
}

ARC_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=0
}
