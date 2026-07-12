#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_SHARE_DIR"
ARC_LABEL="muRetro Data"

ARC_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

ARC_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=9
}

# The extract/patched directories are wiped on every content launch, and archive is the
# VFS extraction cache which regenerates on demand, so none of them belong in a backup!
ARC_CREATE_PRE() {
	for TRANSIENT in extract patched archive; do
		[ -d "$ARC_DIR/retro/$TRANSIENT" ] && rm -rf "${ARC_DIR:?}/retro/$TRANSIENT"
	done

	return 0
}
