#!/bin/sh
# shellcheck disable=SC2034

SETTINGS_ARC_DIR="$MUOS_RUN_DIR/settings-archive"
ARC_DIR="$SETTINGS_ARC_DIR"
ARC_LABEL="MustardOS Settings"

SETTINGS_TRIM() {
	for SETTINGS_SKIP in system boot extra bluetooth g350-pstore; do
		rm -rf "$SETTINGS_ARC_DIR/settings/$SETTINGS_SKIP"
	done
	rm -f "$SETTINGS_ARC_DIR/settings/settings/general/audiosink"
}

ARC_EXTRACT() {
	DEST="$SETTINGS_ARC_DIR"
	LABEL="$ARC_LABEL"
}

ARC_EXTRACT_PRE() {
	rm -rf "$SETTINGS_ARC_DIR"
	mkdir -p "$SETTINGS_ARC_DIR"
}

ARC_EXTRACT_POST() {
	if [ "$1" -ne 0 ] || [ ! -d "$SETTINGS_ARC_DIR/settings" ]; then
		rm -rf "$SETTINGS_ARC_DIR"
		return 1
	fi

	SETTINGS_TRIM
	printf "Restoring settings...\n"
	cp -R "$SETTINGS_ARC_DIR/settings/." "$MUOS_CONF_GLOBAL/" || {
		rm -rf "$SETTINGS_ARC_DIR"
		return 1
	}

	[ -x "$MUOS_VAR_BIN" ] && "$MUOS_VAR_BIN" build
	rm -rf "$SETTINGS_ARC_DIR"
}

ARC_CREATE() {
	SRC="$SETTINGS_ARC_DIR"
	LABEL="$ARC_LABEL"
	COMP=9
}

ARC_CREATE_PRE() {
	rm -rf "$SETTINGS_ARC_DIR"
	mkdir -p "$SETTINGS_ARC_DIR/settings" || return 1
	cp -R "$MUOS_CONF_GLOBAL/." "$SETTINGS_ARC_DIR/settings/" || return 1
	SETTINGS_TRIM
}

ARC_CREATE_POST() {
	rm -rf "$SETTINGS_ARC_DIR"
}
