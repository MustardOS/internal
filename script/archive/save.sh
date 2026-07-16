#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_STORE_DIR"
ARC_LABEL="Save Game Files"

ARC_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

ARC_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=9
}

# The extract/patched/archive directories under Pickles are wiped on every content launch,
# or (for archive) regenerate on demand as the VFS extraction cache, so none belong in a backup!
ARC_CREATE_PRE() {
	for TRANSIENT in extract patched archive; do
		[ -d "$ARC_DIR/save/pickles/$TRANSIENT" ] && rm -rf "${ARC_DIR:?}/save/pickles/$TRANSIENT"
	done

	return 0
}
