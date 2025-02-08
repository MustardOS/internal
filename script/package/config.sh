#!/bin/sh

. /opt/muos/script/var/func.sh

COMMAND=$(basename "$0")

USAGE() {
	printf "Usage: %s <install|save> <configuration>\n" "$COMMAND"
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
CONFIG_ARG="$2"
CONFIG_DIR="/run/muos/storage/info/config"
CONFIG_ZIP_DIR="/run/muos/storage/package/config"

INSTALL() {
	[ -d "$CONFIG_DIR" ] && {
		printf "Purging configuration directory: %s\n" "$CONFIG_DIR"
		find "$CONFIG_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
		sync
	}

	CONFIG_ZIP="$CONFIG_ZIP_DIR/$CONFIG_ARG.muxcfg"
	[ ! -f "$CONFIG_ZIP" ] && {
		printf "Configuration zip not found: %s\n" "$CONFIG_ZIP"
		exit 1
	}

	printf "Unzipping configuration: %s\n" "$CONFIG_ZIP"
	unzip -q "$CONFIG_ZIP" -d "$CONFIG_DIR" && sync

	printf "Restoring device control configuration\n"
	/opt/muos/device/current/script/control.sh

	CLEANED_CONFIG_NAME=$(printf "%s\n" "$CONFIG_ARG" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
	printf "%s\n" "$CLEANED_CONFIG_NAME" >"$CONFIG_DIR/name.txt"

	printf "Install complete\n"
	sync
}

SAVE() {
	[ ! -d "$CONFIG_DIR" ] && {
		printf "Source directory not found: %s\n" "$CONFIG_DIR"
		exit 1
	}

	# Let's remove retro achievement values just in case!
	sed -i '/^cheevos_.*=/s/=.*/=""/' "$CONFIG_DIR/retroarch.cfg"

	if [ -f "$CONFIG_DIR/name.txt" ]; then
		BASE_CONFIG_NAME=$(sed -n '1p' "$CONFIG_DIR/name.txt")
	else
		BASE_CONFIG_NAME="current_config"
		printf "Using default configuration name: %s\n" "$BASE_CONFIG_NAME"
	fi

	TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
	DEST_FILE="$CONFIG_ZIP_DIR/$BASE_CONFIG_NAME-$TIMESTAMP.muxcfg"

	printf "Backing up contents of %s to %s\n" "$CONFIG_DIR" "$DEST_FILE"
	cd "$CONFIG_DIR" && zip -9r "$DEST_FILE" .

	printf "Backup complete: %s\n" "$DEST_FILE"
	sync
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	*) USAGE ;;
esac
