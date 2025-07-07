#!/bin/sh

. /opt/muos/script/var/func.sh

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
THEME_DIR="/run/muos/storage/theme"
THEME_ACTIVE_DIR="$THEME_DIR/active"
BOOTLOGO_MOUNT="$(GET_VAR "device" "storage/boot/mount")"

INSTALL() {
	#if [ "$THEME_ARG" = "?R" ] && [ "$(GET_VAR "config" "settings/advanced/random_theme")" -eq 1 ]; then
	#	THEME=$(find "$THEME_DIR" -name '*.muxthm' | shuf -n 1)
	#else
		THEME="$THEME_DIR/$THEME_ARG.muxthm"
	#fi

	cp "/opt/muos/device/bootlogo.bmp" "$BOOTLOGO_MOUNT/bootlogo.bmp"

	printf "Checking for processes using theme media files...\n"
	for EXT in ogg wav ttf; do
		if lsof +D "$THEME_ACTIVE_DIR" 2>/dev/null | grep -i "\.$EXT" >/dev/null; then
			printf "Killing processes using '%s' files...\n" "$EXT"
			for PID in $(lsof +D "$THEME_ACTIVE_DIR" 2>/dev/null | grep -i "\.$EXT" | awk '{print $2}' | sort -u); do
				kill -9 "$PID" 2>/dev/null
			done
			/opt/muos/bin/toybox sleep 1
		fi
	done

	while [ -d "$THEME_ACTIVE_DIR" ]; do
		rm -rf "$THEME_ACTIVE_DIR"
		sync
		/opt/muos/bin/toybox sleep 1
	done

	unzip "$THEME" -d "$THEME_ACTIVE_DIR"

	THEME_NAME=$(basename "$THEME" .muxthm)
	echo "${THEME_NAME%-[0-9]*_[0-9]*}" >"$THEME_ACTIVE_DIR/name.txt"

	BOOTLOGO_NEW="$THEME_ACTIVE_DIR/$(GET_VAR "device" "mux/width")x$(GET_VAR "device" "mux/height")/image/bootlogo.bmp"
	[ -f "$BOOTLOGO_NEW" ] || BOOTLOGO_NEW="$THEME_ACTIVE_DIR/image/bootlogo.bmp"

	(
		LED_CONTROL_SCRIPT="/opt/muos/device/script/led_control.sh"

		if [ "$(GET_VAR "config" "settings/general/rgb")" -eq 1 ] && [ "$(GET_VAR "device" "led/rgb")" -eq 1 ]; then
			RGBCONF_SCRIPT="$THEME_ACTIVE_DIR/rgb/rgbconf.sh"

			TIMEOUT=10
			WAIT=0

			while [ ! -f "$RGBCONF_SCRIPT" ] && [ "$WAIT" -lt "$TIMEOUT" ]; do
				sleep 1
				WAIT=$((WAIT + 1))
			done

			if [ -f "$RGBCONF_SCRIPT" ]; then
				"$RGBCONF_SCRIPT"
			else
				"$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
			fi
		else
			[ -f "$LED_CONTROL_SCRIPT" ] && "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
		fi
	) &

	if [ -f "$BOOTLOGO_NEW" ]; then
		cp "$BOOTLOGO_NEW" "$BOOTLOGO_MOUNT/bootlogo.bmp"
		case "$(GET_VAR "device" "board/name")" in
			rg28xx-h) convert "$BOOTLOGO_MOUNT/bootlogo.bmp" -rotate 270 "$BOOTLOGO_MOUNT/bootlogo.bmp" ;;
		esac
	fi

	ASSETS_ZIP="$THEME_ACTIVE_DIR/assets.muxzip"
	if [ -f "$ASSETS_ZIP" ]; then
		printf "Extracting theme assets\n"
		/opt/muos/script/mux/extract.sh "$ASSETS_ZIP"
	fi

	printf "Install complete\n"
	sync

	FRONTEND start picker
}

SAVE() {
	if [ -f "$THEME_ACTIVE_DIR/name.txt" ]; then
		BASE_THEME_NAME=$(sed -n '1p' "$THEME_ACTIVE_DIR/name.txt")
	else
		BASE_THEME_NAME="current_theme"
		printf "Using default theme name: %s\n" "$BASE_THEME_NAME"
	fi

	TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
	DEST_FILE="$THEME_DIR/$BASE_THEME_NAME-$TIMESTAMP.muxthm"

	printf "Backing up contents of %s to %s\n" "$THEME_ACTIVE_DIR" "$DEST_FILE"
	cd "$THEME_ACTIVE_DIR" && zip -9r "$DEST_FILE" .

	printf "Backup complete: %s\n" "$DEST_FILE"
	sync

	FRONTEND start picker
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	*) USAGE ;;
esac
