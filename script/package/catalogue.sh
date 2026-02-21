#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

FRONTEND stop

COMMAND=$(basename "$0")

USAGE() {
	printf "Usage: %s <install|save> <catalogue>\n" "$COMMAND"
	FRONTEND start picker
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
CATALOGUE_ARG="$2"
CATALOGUE_DIR="$MUOS_STORE_DIR/info/catalogue"
CATALOGUE_ZIP_DIR="$MUOS_STORE_DIR/package/catalogue"

ALL_DONE() {
	printf "\nSync Filesystem\n"
	sync

	printf "All Done!\n"
	sleep 2
	FRONTEND start picker

	exit "${1:-0}"
}

INSTALL() {
	CATALOGUE_ZIP="$CATALOGUE_ZIP_DIR/$CATALOGUE_ARG.muxcat"
	[ ! -f "$CATALOGUE_ZIP" ] && {
		printf "Catalogue Package Not Found: %s\n" "$CATALOGUE_ZIP"
		exit 1
	}

	CHECK_ARCHIVE "$CATALOGUE_ZIP"
	CAT_GRID_CLEAR "$CATALOGUE_ZIP"

	SPACE_REQ="$(GET_ARCHIVE_BYTES "$CATALOGUE_ZIP" "")"
	! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$CATALOGUE_DIR" "catalogue" && {
		printf "Not enough space to extract catalogue\n"
		ALL_DONE 1
	}

	[ -d "$CATALOGUE_DIR" ] && {
		printf "Purging Catalogue Directory: %s\n\n" "$CATALOGUE_DIR"
		find "$CATALOGUE_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
		sync
	}

	printf "Extracting to Catalogue Directory: %s\n" "$CATALOGUE_DIR"

	if ! EXTRACT_ARCHIVE "Catalogue" "$CATALOGUE_ZIP" "$CATALOGUE_DIR"; then
		printf "\nExtraction Failed...\n"
		ALL_DONE 1
	fi

	printf "Running Catalogue Generation\n"
	/opt/muos/script/system/catalogue.sh

	CLEANED_CATALOGUE_NAME=$(printf "%s\n" "$CATALOGUE_ARG" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
	printf "%s\n" "$CLEANED_CATALOGUE_NAME" >"$CATALOGUE_DIR/name.txt"

	printf "Install Complete\n"
	ALL_DONE 0
}

SAVE() {
	[ ! -d "$CATALOGUE_DIR" ] && {
		printf "Source Directory Not Found: %s\n" "$CATALOGUE_DIR"
		exit 1
	}

	if [ -f "$CATALOGUE_DIR/name.txt" ]; then
		BASE_CATALOGUE_NAME=$(sed -n '1p' "$CATALOGUE_DIR/name.txt")
	else
		BASE_CATALOGUE_NAME="current_catalogue"
		printf "Using Default Catalogue Name: %s\n" "$BASE_CATALOGUE_NAME"
	fi

	TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
	DEST_FILE="$CATALOGUE_ZIP_DIR/$BASE_CATALOGUE_NAME-$TIMESTAMP.muxcat"

	printf "Backing Up Contents of '%s' to '%s'\n" "$CATALOGUE_DIR" "$DEST_FILE"
	cd "$CATALOGUE_DIR" && zip -ru0 "$DEST_FILE" .

	printf "Backup Complete: %s\n" "$DEST_FILE"
	ALL_DONE 0
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	*) USAGE ;;
esac
