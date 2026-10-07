#!/bin/sh
# shellcheck disable=SC2034

ARC_DIR="$MUOS_RUN_DIR/settings-archive"
ARC_LABEL="MustardOS Settings"

SETTINGS_TRIM() {
	for SETTINGS_SKIP in system boot extra bluetooth g350-pstore; do
		rm -rf "$ARC_DIR/settings/$SETTINGS_SKIP"
	done
	rm -f "$ARC_DIR/settings/settings/general/audiosink"
}

ARC_EXTRACT() {
	DEST="$ARC_DIR"
	LABEL="$ARC_LABEL"
}

ARC_EXTRACT_PRE() {
	rm -rf "$ARC_DIR"
	mkdir -p "$ARC_DIR"
}

ARC_EXTRACT_POST() {
	if [ "$1" -ne 0 ] || [ ! -d "$ARC_DIR/settings" ]; then
		rm -rf "$ARC_DIR"
		return 1
	fi

	SETTINGS_TRIM
	printf "Restoring settings...\n"
	cp -R "$ARC_DIR/settings/." "$MUOS_CONF_GLOBAL/" || {
		rm -rf "$ARC_DIR"
		return 1
	}

	[ -x "$MUOS_VAR_BIN" ] && "$MUOS_VAR_BIN" build
	rm -rf "$ARC_DIR"
}

ARC_CREATE() {
	SRC="$ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=9
}

ARC_CREATE_PRE() {
	rm -rf "$ARC_DIR"
	mkdir -p "$ARC_DIR/settings" || return 1
	cp -R "$MUOS_CONF_GLOBAL/." "$ARC_DIR/settings/" || return 1
	SETTINGS_TRIM
}

ARC_CREATE_POST() {
	rm -rf "$ARC_DIR"
}
