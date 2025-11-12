#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

FRONTEND stop

COMMAND=$(basename "$0")

USAGE() {
	printf "Usage: %s <install|save|bootlogo> <theme>\n" "$COMMAND"
	FRONTEND start picker
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
THEME_ARG="$2"
THEME_EXT="muxthm"
THEME_DIR="$MUOS_STORE_DIR/theme"
THEME_ACTIVE_DIR="$THEME_DIR/active"

LOCK_DIR="$THEME_DIR/.theme.lock"
if ! touch "$LOCK_DIR" 2>/dev/null; then
	printf "Another Theme Operation is in progress. Please try again shortly...\n"
	TBOX sleep 2

	FRONTEND start picker
	exit 1
fi

ALL_DONE() {
	FE_CMD="${2:-picker}"
	printf "\nSync Filesystem\n"
	sync

	printf "All Done!\n"
	TBOX sleep 2
	FRONTEND start "$FE_CMD"

	exit "${1:-0}"
}

INSTALL() {
	#if [ "$THEME_ARG" = "?R" ] && [ "$(GET_VAR "config" "settings/advanced/random_theme")" -eq 1 ]; then
	#	THEME_ZIP=$(find "$THEME_DIR" -name '*.${THEME_EXT}' | shuf -n 1)
	#else
		THEME_ZIP="$THEME_DIR/$THEME_ARG.${THEME_EXT}"
	#fi

	if [ ! -f "$THEME_ZIP" ]; then
		printf "Theme Archive Not Found: %s\n" "$THEME_ZIP"
		ALL_DONE 1
	fi

	printf "Checking for Processes using Active Theme...\n"
	PIDS=$(lsof +D "$THEME_ACTIVE_DIR" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
	if [ -n "$PIDS" ]; then
		SELF=$$
		PIDS=$(printf "%s\n" $PIDS | awk -v self="$SELF" '$1 != self')
		if [ -n "$PIDS" ]; then
			for PID in $PIDS; do kill "$PID" 2>/dev/null; done
			TBOX sleep 0.5

			for PID in $PIDS; do kill -0 "$PID" 2>/dev/null && kill -9 "$PID" 2>/dev/null; done
			TBOX sleep 0.25
		fi
	fi

	NEW_DIR="$(mktemp -d "$THEME_DIR/.new.XXXXXX")" || {
		printf "Failed to create temp dir\n"
		ALL_DONE 1
	}

	CHECK_ARCHIVE "$THEME_ZIP"

	SPACE_REQ="$(GET_ARCHIVE_BYTES "$THEME_ZIP" "")"
	! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$NEW_DIR" && {
		printf "Not enough space to extract theme\n"
		ALL_DONE 1
	}

	if ! EXTRACT_ARCHIVE "Theme" "$THEME_ZIP" "$NEW_DIR"; then
		printf "\nExtraction Failed...\n"
		ALL_DONE 1
	fi

	THEME_NAME=$(basename "$THEME_ZIP" .${THEME_EXT})
	[ ! -f "$NEW_DIR/name.txt" ] && printf "%s\n" "${THEME_NAME%-[0-9]*_[0-9]*}" >"$NEW_DIR/name.txt"

	OLD_DIR="$THEME_DIR/.active.old.$$"

	printf "\nActivating Theme\n"
	if [ -d "$THEME_ACTIVE_DIR" ]; then
		mv "$THEME_ACTIVE_DIR" "$OLD_DIR" 2>/dev/null || {
			printf "Rename Failure...\n\tAttempting Fallback Purge\n"
			find "$THEME_ACTIVE_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
			OLD_DIR=
		}
	fi

	if ! mv "$NEW_DIR" "$THEME_ACTIVE_DIR" 2>/dev/null; then
		printf "Theme Move Failure...\n\tReverting to copying theme into place\n"
		mkdir -p "$THEME_ACTIVE_DIR" 2>/dev/null
		if ! cp -a "$NEW_DIR"/. "$THEME_ACTIVE_DIR"/ 2>/dev/null; then
			printf "Failed to Activate Theme\n"
			[ -n "$OLD_DIR" ] && mv "$OLD_DIR" "$THEME_ACTIVE_DIR" 2>/dev/null
			ALL_DONE 1
		fi

		rm -rf "$NEW_DIR" >/dev/null 2>&1
		NEW_DIR=
	fi

	if [ -n "$OLD_DIR" ] && [ -d "$OLD_DIR" ]; then
		(
			chmod -R u+w "$OLD_DIR" 2>/dev/null
			rm -rf "$OLD_DIR" >/dev/null 2>&1
		) &
	fi

	if ! UPDATE_BOOTLOGO_PNG; then
		UPDATE_BOOTLOGO
	fi

	LED_CONTROL_CHANGE

	ASSETS_ZIP="$THEME_ACTIVE_DIR/assets.muxzip"
	if [ -f "$ASSETS_ZIP" ]; then
		CAT_GRID_CLEAR "$ASSETS_ZIP"
		printf "Extracting Theme Assets\n"

		export THEME_INSTALLING=1
		/opt/muos/script/mux/extract.sh "$ASSETS_ZIP" picker
		unset THEME_INSTALLING
	fi

	rm -f "$LOCK_DIR"

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
	DEST_FILE="$THEME_DIR/$BASE_THEME_NAME-$TIMESTAMP.${THEME_EXT}"

	printf "Backing up Contents of '%s' to '%s'\n" "$THEME_ACTIVE_DIR" "$DEST_FILE"
	cd "$THEME_ACTIVE_DIR" && zip -ru "$DEST_FILE" .

	printf "Backup Complete: %s\n" "$DEST_FILE"
	ALL_DONE 0
}

BOOTLOGO() {
	if ! UPDATE_BOOTLOGO_PNG; then
		UPDATE_BOOTLOGO
	fi

	printf "Bootlogo Updated\n"
	ALL_DONE 0 "${THEME_ARG:-custom}"
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	bootlogo) BOOTLOGO ;;
	*) USAGE ;;
esac
