#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

FRONTEND stop

COMMAND=$(basename "$0")

USAGE() {
	printf "Usage: %s <install|save> <theme>\n" "$COMMAND"
	FRONTEND start picker
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
THEME_ARG="$2"
THEME_DIR="$MUOS_STORE_DIR/theme"
THEME_ACTIVE_DIR="$THEME_DIR/active"

ALL_DONE() {
	printf "\nSync Filesystem\n"
	sync

	printf "All Done!\n"
	TBOX sleep 2
	FRONTEND start picker

	exit "${1:-0}"
}

INSTALL() {
	#if [ "$THEME_ARG" = "?R" ] && [ "$(GET_VAR "config" "settings/advanced/random_theme")" -eq 1 ]; then
	#	THEME_ZIP=$(find "$THEME_DIR" -name '*.muxthm' | shuf -n 1)
	#else
		THEME_ZIP="$THEME_DIR/$THEME_ARG.muxthm"
	#fi

	printf "Checking for processes using theme media files...\n"
	for EXT in ogg wav ttf; do
		if lsof +D "$THEME_ACTIVE_DIR" 2>/dev/null | grep -i "\.$EXT" >/dev/null; then
			printf "Killing processes using '%s' files...\n" "$EXT"
			for PID in $(lsof +D "$THEME_ACTIVE_DIR" 2>/dev/null | grep -i "\.$EXT" | awk '{print $2}' | sort -u); do
				kill -9 "$PID" 2>/dev/null
			done
			TBOX sleep 1
		fi
	done

	printf "Purging Active Theme"
	while [ -d "$THEME_ACTIVE_DIR" ]; do
		rm -rf "$THEME_ACTIVE_DIR"
		sync
		TBOX sleep 1
	done

	mkdir -p "$THEME_ACTIVE_DIR"

	CHECK_ARCHIVE "$THEME_ZIP"
	CAT_GRID_CLEAR "$THEME_ZIP"

	SPACE_REQ="$(GET_ARCHIVE_BYTES "$THEME_ZIP" "")"
	! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$THEME_ACTIVE_DIR" && ALL_DONE 1

	if ! EXTRACT_ARCHIVE "Theme" "$THEME_ZIP" "$THEME_ACTIVE_DIR"; then
		printf "\nExtraction Failed...\n"
		ALL_DONE 1
	fi

	THEME_NAME=$(basename "$THEME_ZIP" .muxthm)
	[ -f "$THEME_ACTIVE_DIR/name.txt" ] && echo "${THEME_NAME%-[0-9]*_[0-9]*}" >"$THEME_ACTIVE_DIR/name.txt"

	UPDATE_BOOTLOGO
	LED_CONTROL_CHANGE

	ASSETS_ZIP="$THEME_ACTIVE_DIR/assets.muxzip"
	if [ -f "$ASSETS_ZIP" ]; then
		printf "Extracting Theme Assets\n"
		/opt/muos/script/mux/extract.sh "$ASSETS_ZIP" picker
	fi

	printf "Install Complete\n"
	ALL_DONE 0
}

SAVE() {
	if [ -f "$THEME_ACTIVE_DIR/name.txt" ]; then
		BASE_THEME_NAME=$(sed -n '1p' "$THEME_ACTIVE_DIR/name.txt")
	else
		BASE_THEME_NAME="current_theme"
		printf "Using Default Theme Name: %s\n" "$BASE_THEME_NAME"
	fi

	TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
	DEST_FILE="$THEME_DIR/$BASE_THEME_NAME-$TIMESTAMP.muxthm"

	printf "Backing up Contents of '%s' to '%s'\n" "$THEME_ACTIVE_DIR" "$DEST_FILE"
	cd "$THEME_ACTIVE_DIR" && zip -ru0 "$DEST_FILE" .

	printf "Backup Complete: %s\n" "$DEST_FILE"
	ALL_DONE 0
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	*) USAGE ;;
esac
