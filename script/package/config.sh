#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

FRONTEND stop

COMMAND=$(basename "$0")

USAGE() {
	printf "Usage: %s <install|save> <configuration>\n" "$COMMAND"
	FRONTEND start picker
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
CONFIG_ARG="$2"
CONFIG_DIR="$MUOS_SHARE_DIR/info/config"
CONFIG_ZIP_DIR="$MUOS_STORE_DIR/package/config"

ALL_DONE() {
	printf "\nSync Filesystem\n"
	sync

	printf "All Done!\n"
	TBOX sleep 2
	FRONTEND start picker

	exit "${1:-0}"
}

INSTALL() {
	[ -d "$CONFIG_DIR" ] && {
		printf "Purging Configuration Directory: %s\n" "$CONFIG_DIR"
		find "$CONFIG_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
		sync
	}

	CONFIG_ZIP="$CONFIG_ZIP_DIR/$CONFIG_ARG.muxcfg"
	[ ! -f "$CONFIG_ZIP" ] && {
		printf "Configuration Package Not Found: %s\n" "$CONFIG_ZIP"
		exit 1
	}

	SPACE_REQ="$(GET_ARCHIVE_BYTES "$CONFIG_ZIP" "")"
	! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$CONFIG_DIR" && ALL_DONE 1

	if ! EXTRACT_ARCHIVE "Configuration" "$CONFIG_ZIP" "$CONFIG_DIR"; then
		printf "\nExtraction Failed...\n"
		ALL_DONE 1
	fi

	printf "Running Device Control Configuration\n"
	/opt/muos/script/device/control.sh

	CLEANED_CONFIG_NAME=$(printf "%s\n" "$CONFIG_ARG" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
	printf "%s\n" "$CLEANED_CONFIG_NAME" >"$CONFIG_DIR/name.txt"

	printf "Install Complete\n"
	ALL_DONE 0
}

SAVE() {
	[ ! -d "$CONFIG_DIR" ] && {
		printf "Source Directory Not Found: %s\n" "$CONFIG_DIR"
		exit 1
	}

	# Let's remove retro achievement values just in case!
	sed -i '/^cheevos_.*=/s/=.*/=""/' "$CONFIG_DIR/retroarch.cfg"

	if [ -f "$CONFIG_DIR/name.txt" ]; then
		BASE_CONFIG_NAME=$(sed -n '1p' "$CONFIG_DIR/name.txt")
	else
		BASE_CONFIG_NAME="current_config"
		printf "Using Default Configuration Name: %s\n" "$BASE_CONFIG_NAME"
	fi

	TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
	DEST_FILE="$CONFIG_ZIP_DIR/$BASE_CONFIG_NAME-$TIMESTAMP.muxcfg"

	printf "Backing Up Contents of '%s' to '%s'\n" "$CONFIG_DIR" "$DEST_FILE"
	cd "$CONFIG_DIR" && zip -ru0 "$DEST_FILE" .

	printf "Backup Complete: %s\n" "$DEST_FILE"
	ALL_DONE 0
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	*) USAGE ;;
esac
