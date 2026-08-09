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
	TASK_ERROR "bad_arguments" "$(printf "Usage: %s <install|save> <configuration>" "$COMMAND")"
	TASK_IS_NATIVE || FRONTEND start picker
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
CONFIG_ARG="$2"
CONFIG_DIR="$MUOS_SHARE_DIR/info/config"
CONFIG_ZIP_DIR="$MUOS_STORE_DIR/package/config"

ALL_DONE() {
	ARCHIVE_CACHE_CLEANUP
	TASK_STATUS "Sync Filesystem"
	sync

	# A failure has already reported itself, saying it completed would overwrite that
	[ "${1:-0}" -eq 0 ] && TASK_COMPLETE "$DONE_MESSAGE"
	TASK_IS_NATIVE || {
		sleep 2
		FRONTEND start picker
	}

	exit "${1:-0}"
}

INSTALL() {
	CONFIG_ZIP="$CONFIG_ZIP_DIR/$CONFIG_ARG.muxcfg"
	[ ! -f "$CONFIG_ZIP" ] && {
		TASK_ERROR "package_missing" "$(printf "Configuration package not found: %s" "$CONFIG_ZIP")"
		ALL_DONE 1
	}

	SPACE_REQ="$(GET_ARCHIVE_BYTES "$CONFIG_ZIP" "")"
	TASK_DETAIL "$(printf "Space required: %s bytes" "$SPACE_REQ")"
	CURRENT_SPACE=$(du -sb "$CONFIG_DIR" | cut -f1)
	SPACE_REQ=$((SPACE_REQ - CURRENT_SPACE))
	! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$CONFIG_DIR" "config" && {
		TASK_ERROR "no_space" "There is not enough space to extract the package."
		ALL_DONE 1
	}

	[ -d "$CONFIG_DIR" ] && {
		TASK_STATUS "Purging Configuration Directory"
		find "$CONFIG_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
		sync
	}

	TASK_STATUS "Extracting Configuration Package"

	if ! EXTRACT_ARCHIVE "Configuration" "$CONFIG_ZIP" "$CONFIG_DIR"; then
		TASK_ERROR "extract_failed" "The package could not be extracted."
		ALL_DONE 1
	fi

	TASK_STATUS "Device Control Configuration"
	/opt/muos/script/device/control.sh

	CLEANED_CONFIG_NAME=$(printf "%s\n" "$CONFIG_ARG" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
	printf "%s\n" "$CLEANED_CONFIG_NAME" >"$CONFIG_DIR/name.txt"

	DONE_MESSAGE="Configuration package installed"
	ALL_DONE 0
}

SAVE() {
	[ ! -d "$CONFIG_DIR" ] && {
		TASK_ERROR "source_missing" "$(printf "Source directory not found: %s" "$CONFIG_DIR")"
		ALL_DONE 1
	}

	# Let's remove retro achievement values just in case!
	sed -i '/^cheevos_.*=/s/=.*/=""/' "$CONFIG_DIR/retroarch.cfg"

	if [ -f "$CONFIG_DIR/name.txt" ]; then
		BASE_CONFIG_NAME=$(sed -n '1p' "$CONFIG_DIR/name.txt")
	else
		BASE_CONFIG_NAME="current_config"
		TASK_DETAIL "$(printf "Using the default name: %s" "$BASE_CONFIG_NAME")"
	fi

	TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
	DEST_FILE="$CONFIG_ZIP_DIR/$BASE_CONFIG_NAME-$TIMESTAMP.muxcfg"

	TASK_STATUS "Creating Package"
	TASK_DETAIL "$DEST_FILE"
	cd "$CONFIG_DIR" && zip -ru0 "$DEST_FILE" .

	DONE_MESSAGE="Configuration package saved"
	ALL_DONE 0
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	*) USAGE ;;
esac
