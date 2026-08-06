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
	TASK_ERROR "bad_arguments" "$(printf "Usage: %s <install|save> <catalogue>" "$COMMAND")"
	TASK_IS_NATIVE || FRONTEND start picker
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
CATALOGUE_ARG="$2"
CATALOGUE_DIR="$MUOS_STORE_DIR/info/catalogue"
CATALOGUE_ZIP_DIR="$MUOS_STORE_DIR/package/catalogue"

ALL_DONE() {
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
	CATALOGUE_ZIP="$CATALOGUE_ZIP_DIR/$CATALOGUE_ARG.muxcat"
	[ ! -f "$CATALOGUE_ZIP" ] && {
		TASK_ERROR "package_missing" "$(printf "Catalogue package not found: %s" "$CATALOGUE_ZIP")"
		ALL_DONE 1
	}

	CHECK_ARCHIVE "$CATALOGUE_ZIP"
	CAT_GRID_CLEAR "$CATALOGUE_ZIP"

	SPACE_REQ="$(GET_ARCHIVE_BYTES "$CATALOGUE_ZIP" "")"
	TASK_DETAIL "$(printf "Space required: %s bytes" "$SPACE_REQ")"
	CURRENT_SPACE=$(du -sb "$CATALOGUE_DIR" | cut -f1)
	SPACE_REQ=$((SPACE_REQ - CURRENT_SPACE))
	! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$CATALOGUE_DIR" "catalogue" && {
		TASK_ERROR "no_space" "There is not enough space to extract the package."
		ALL_DONE 1
	}

	[ -d "$CATALOGUE_DIR" ] && {
		TASK_STATUS "Purging Catalogue Directory"
		find "$CATALOGUE_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
		sync
	}

	TASK_STATUS "Extracting Catalogue Package"

	if ! EXTRACT_ARCHIVE "Catalogue" "$CATALOGUE_ZIP" "$CATALOGUE_DIR"; then
		TASK_ERROR "extract_failed" "The package could not be extracted."
		ALL_DONE 1
	fi

	TASK_STATUS "Catalogue Generation"
	/opt/muos/script/system/catalogue.sh

	CLEANED_CATALOGUE_NAME=$(printf "%s\n" "$CATALOGUE_ARG" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
	printf "%s\n" "$CLEANED_CATALOGUE_NAME" >"$CATALOGUE_DIR/name.txt"

	DONE_MESSAGE="Catalogue package installed"
	ALL_DONE 0
}

SAVE() {
	[ ! -d "$CATALOGUE_DIR" ] && {
		TASK_ERROR "source_missing" "$(printf "Source directory not found: %s" "$CATALOGUE_DIR")"
		ALL_DONE 1
	}

	if [ -f "$CATALOGUE_DIR/name.txt" ]; then
		BASE_CATALOGUE_NAME=$(sed -n '1p' "$CATALOGUE_DIR/name.txt")
	else
		BASE_CATALOGUE_NAME="current_catalogue"
		TASK_DETAIL "$(printf "Using the default name: %s" "$BASE_CATALOGUE_NAME")"
	fi

	TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
	DEST_FILE="$CATALOGUE_ZIP_DIR/$BASE_CATALOGUE_NAME-$TIMESTAMP.muxcat"

	TASK_STATUS "Creating Package"
	TASK_DETAIL "$DEST_FILE"
	cd "$CATALOGUE_DIR" && zip -ru0 "$DEST_FILE" .

	DONE_MESSAGE="Catalogue package saved"
	ALL_DONE 0
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	*) USAGE ;;
esac
