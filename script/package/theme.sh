#!/bin/sh
# NEVER_CANCEL: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh
. /opt/muos/script/var/ui.sh

TASK_IS_NATIVE || FRONTEND stop

COMMAND=$(basename "$0")

# Set by whichever path ran so the completion text matches what actually happened
DONE_MESSAGE="Done"

USAGE() {
	TASK_ERROR "bad_arguments" "$(printf "Usage: %s <install|save|bootlogo> <theme>" "$COMMAND")"
	TASK_IS_NATIVE || FRONTEND start picker
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
THEME_ARG="$2"
THEME_EXT="muxthm"
THEME_DIR="$MUOS_STORE_DIR/theme"
THEME_ACTIVE_DIR="$THEME_DIR/active"

LOCK_DIR="$THEME_DIR/.theme.lock"
LOCK_HELD=0

CLEANUP() {
	ARCHIVE_CACHE_CLEANUP
	if [ "$LOCK_HELD" -eq 1 ]; then
		rm -f "$LOCK_DIR/pid" "$LOCK_DIR/start" 2>/dev/null
		rmdir "$LOCK_DIR" 2>/dev/null
	fi
}

ACQUIRE_LOCK() {
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		LOCK_HELD=1
	else
		LOCK_PID="$(cat "$LOCK_DIR/pid" 2>/dev/null)"
		LOCK_START="$(cat "$LOCK_DIR/start" 2>/dev/null)"
		CURRENT_START=""
		case "$LOCK_PID" in '' | *[!0-9]*) ;; *) CURRENT_START="$(awk '{print $22}' "/proc/$LOCK_PID/stat" 2>/dev/null)" ;; esac
		[ -n "$CURRENT_START" ] && [ "$CURRENT_START" = "$LOCK_START" ] && return 1
		rm -f "$LOCK_DIR/pid" "$LOCK_DIR/start" 2>/dev/null
		rmdir "$LOCK_DIR" 2>/dev/null || return 1
		mkdir "$LOCK_DIR" 2>/dev/null || return 1
		LOCK_HELD=1
	fi

	printf '%s\n' "$$" >"$LOCK_DIR/pid" || return 1
	awk '{print $22}' "/proc/$$/stat" >"$LOCK_DIR/start" 2>/dev/null || return 1
	return 0
}

trap 'CLEANUP' EXIT
trap 'exit 1' HUP INT TERM

if ! ACQUIRE_LOCK; then
	TASK_ERROR "theme_locked" "Another theme operation is already in progress."
	TASK_IS_NATIVE || {
		sleep 2
		FRONTEND start picker
	}
	exit 1
fi

ALL_DONE() {
	FE_CMD="${2:-picker}"
	TASK_STATUS "Sync Filesystem"
	sync

	# A failure has already reported itself, saying it completed would overwrite that
	[ "${1:-0}" -eq 0 ] && TASK_COMPLETE "$DONE_MESSAGE"
	TASK_IS_NATIVE || {
		sleep 2
		FRONTEND start "$FE_CMD"
	}

	exit "${1:-0}"
}

RANDOM() {
	TASK_STATUS "Selecting Random Theme"

	selected=$(
		find "$THEME_DIR" \
			-type d \( \
			-name 640x480 -o -name 720x480 -o -name 720x576 -o -name 720x720 -o \
			-name 1024x768 -o -name 1280x720 -o -name alternate -o -name catalogue -o \
			-name font -o -name glyph -o -name image -o -name rgb -o \
			-name scheme -o -name sound \
			\) -prune -o \
			-type f -name version.txt -print |
			awk '
        { files[NR] = $0 }
        END {
            if (NR == 0) exit 1        # No files found
            srand()
            print files[int(rand() * NR) + 1]
        }'
	) || {
		TASK_ERROR "no_themes" "No themes were found to choose from."
		ALL_DONE 1
	}

	relative=${selected#"$THEME_DIR"/}
	relative=${relative%/version.txt}

	TASK_DETAIL "$relative"

	SET_VAR "config" "theme/active" "$relative"
	UPDATE_BOOTLOGO
	DONE_MESSAGE="Theme installed"
	ALL_DONE 0
}

INSTALL() {
	if [ "$THEME_ARG" = "?R" ]; then
		RANDOM
	else
		THEME_ZIP="$THEME_DIR/$THEME_ARG.${THEME_EXT}"
	fi

	if [ ! -f "$THEME_ZIP" ]; then
		TASK_ERROR "theme_missing" "$(printf "Theme archive not found: %s" "$THEME_ZIP")"
		ALL_DONE 1
	fi

	NEW_DIR="$(mktemp -d "$THEME_DIR/.new.XXXXXX")" || {
		TASK_ERROR "temp_failed" "A working directory could not be created."
		ALL_DONE 1
	}

	CHECK_ARCHIVE "$THEME_ZIP"

	SPACE_REQ="$(GET_ARCHIVE_BYTES "$THEME_ZIP" "")"
	! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$NEW_DIR" "theme" && {
		TASK_ERROR "no_space" "There is not enough space to extract the theme."
		ALL_DONE 1
	}

	if ! EXTRACT_ARCHIVE "Theme" "$THEME_ZIP" "$NEW_DIR"; then
		TASK_ERROR "extract_failed" "The theme could not be extracted."
		ALL_DONE 1
	fi

	THEME_NAME=$(basename "$THEME_ZIP" .${THEME_EXT})
	[ ! -f "$NEW_DIR/name.txt" ] && printf "%s\n" "${THEME_NAME%-[0-9]*_[0-9]*}" >"$NEW_DIR/name.txt"

	OLD_DIR="$THEME_DIR/.active.old.$$"

	TASK_STATUS "Activating Theme"
	if [ -d "$THEME_ACTIVE_DIR" ]; then
		mv "$THEME_ACTIVE_DIR" "$OLD_DIR" 2>/dev/null || {
			TASK_DETAIL "Rename failed, purging the active theme instead"
			find "$THEME_ACTIVE_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
			OLD_DIR=
		}
	fi

	if ! mv "$NEW_DIR" "$THEME_ACTIVE_DIR" 2>/dev/null; then
		TASK_DETAIL "Move failed, copying the theme into place instead"
		mkdir -p "$THEME_ACTIVE_DIR" 2>/dev/null
		if ! cp -a "$NEW_DIR"/. "$THEME_ACTIVE_DIR"/ 2>/dev/null; then
			TASK_ERROR "activate_failed" "The theme could not be activated."
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

	UPDATE_BOOTLOGO
	LED_CONTROL_CHANGE restore

	ASSETS_ZIP="$THEME_ACTIVE_DIR/assets.muxzip"
	if [ -f "$ASSETS_ZIP" ]; then
		CAT_GRID_CLEAR "$ASSETS_ZIP"
		TASK_STATUS "Extracting Theme Assets"

		export THEME_INSTALLING=1
		/opt/muos/script/mux/extract.sh "$ASSETS_ZIP" picker
		unset THEME_INSTALLING
	fi

	DONE_MESSAGE="Theme installed"
	ALL_DONE 0
}

SAVE() {
	if [ -f "$THEME_ACTIVE_DIR/name.txt" ]; then
		BASE_THEME_NAME=$(sed -n '1p' "$THEME_ACTIVE_DIR/name.txt")
	else
		BASE_THEME_NAME="current_theme"
		TASK_DETAIL "$(printf "Using the default name: %s" "$BASE_THEME_NAME")"
	fi

	TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
	DEST_FILE="$THEME_DIR/$BASE_THEME_NAME-$TIMESTAMP.${THEME_EXT}"

	TASK_STATUS "Creating Package"
	TASK_DETAIL "$DEST_FILE"
	cd "$THEME_ACTIVE_DIR" || ALL_DONE 1
	zip -ru "$DEST_FILE" .

	DONE_MESSAGE="Theme package saved"
	ALL_DONE 0
}

BOOTLOGO() {
	UPDATE_BOOTLOGO

	DONE_MESSAGE="Bootlogo updated"
	ALL_DONE 0 "${THEME_ARG:-custom}"
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	bootlogo) BOOTLOGO ;;
	*) USAGE ;;
esac
