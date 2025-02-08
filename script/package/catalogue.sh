#!/bin/sh

. /opt/muos/script/var/func.sh

COMMAND=$(basename "$0")

USAGE() {
	printf "Usage: %s <install|save> <catalogue>\n" "$COMMAND"
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
CATALOGUE_ARG="$2"
CATALOGUE_DIR="/run/muos/storage/info/catalogue"
CATALOGUE_ZIP_DIR="/run/muos/storage/package/catalogue"

INSTALL() {
	[ -d "$CATALOGUE_DIR" ] && {
		printf "Purging catalogue directory: %s\n" "$CATALOGUE_DIR"
		find "$CATALOGUE_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
		sync
	}

	CATALOGUE_ZIP="$CATALOGUE_ZIP_DIR/$CATALOGUE_ARG.muxcat"
	[ ! -f "$CATALOGUE_ZIP" ] && {
		printf "Catalogue zip not found: %s\n" "$CATALOGUE_ZIP"
		exit 1
	}

	printf "Unzipping catalogue: %s\n" "$CATALOGUE_ZIP"
	unzip -q "$CATALOGUE_ZIP" -d "$CATALOGUE_DIR" && sync

	printf "Running catalogue generation script\n"
	/opt/muos/script/system/catalogue.sh

	CLEANED_CATALOGUE_NAME=$(printf "%s\n" "$CATALOGUE_ARG" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
	printf "%s\n" "$CLEANED_CATALOGUE_NAME" >"$CATALOGUE_DIR/name.txt"

	printf "Install complete\n"
	sync
}

SAVE() {
	[ ! -d "$CATALOGUE_DIR" ] && {
		printf "Source directory not found: %s\n" "$CATALOGUE_DIR"
		exit 1
	}

	if [ -f "$CATALOGUE_DIR/name.txt" ]; then
		BASE_CATALOGUE_NAME=$(sed -n '1p' "$CATALOGUE_DIR/name.txt")
	else
		BASE_CATALOGUE_NAME="current_catalogue"
		printf "Using default catalogue name: %s\n" "$BASE_CATALOGUE_NAME"
	fi

	TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
	DEST_FILE="$CATALOGUE_ZIP_DIR/$BASE_CATALOGUE_NAME-$TIMESTAMP.muxcat"

	printf "Backing up contents of %s to %s\n" "$CATALOGUE_DIR" "$DEST_FILE"
	cd "$CATALOGUE_DIR" && zip -9r "$DEST_FILE" .

	printf "Backup complete: %s\n" "$DEST_FILE"
	sync
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	*) USAGE ;;
esac
