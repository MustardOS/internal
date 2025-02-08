#!/bin/sh

. /opt/muos/script/var/func.sh

COMMAND=$(basename "$0")

USAGE() {
	printf "Usage: %s <install|save> <theme>\n" "$COMMAND"
	exit 1
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
THEME_ARG="$2"
THEME_DIR="/run/muos/storage/theme"
THEME_ACTIVE_DIR="$THEME_DIR/active"
BOOTLOGO_MOUNT="$(GET_VAR device storage/boot/mount)"

INSTALL() {
	[ "$(GET_VAR "global" "settings/general/bgm")" -eq 2 ] && STOP_BGM

	if [ "$THEME_ARG" = "?R" ] && [ "$(GET_VAR global settings/advanced/random_theme)" -eq 1 ]; then
		THEME=$(find "$THEME_DIR" -name '*.muxthm' | shuf -n 1)
	else
		THEME="$THEME_DIR/$THEME_ARG.muxthm"
	fi

	cp "/opt/muos/device/current/bootlogo.bmp" "$BOOTLOGO_MOUNT/bootlogo.bmp"

	while [ -d "$THEME_ACTIVE_DIR" ]; do
		rm -rf "$THEME_ACTIVE_DIR"
		sync
		sleep 1
	done

	unzip "$THEME" -d "$THEME_ACTIVE_DIR"

	THEME_NAME=$(basename "$THEME" .muxthm)
	echo "${THEME_NAME%-[0-9]*_[0-9]*}" >"$THEME_ACTIVE_DIR/name.txt"

	BOOTLOGO_NEW="$THEME_ACTIVE_DIR/$(GET_VAR device mux/width)x$(GET_VAR device mux/height)/image/bootlogo.bmp"
	[ -f "$BOOTLOGO_NEW" ] || BOOTLOGO_NEW="$THEME_ACTIVE_DIR/image/bootlogo.bmp"

	if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
		RGBCONF_SCRIPT="$THEME_ACTIVE_DIR/rgb/rgbconf.sh"
		[ -f "$RGBCONF_SCRIPT" ] && "$RGBCONF_SCRIPT" || /opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
	fi

	if [ "$(GET_VAR global settings/advanced/random_theme)" -eq 0 ] && [ -f "$BOOTLOGO_NEW" ]; then
		cp "$BOOTLOGO_NEW" "$BOOTLOGO_MOUNT/bootlogo.bmp"
		case "$(GET_VAR device board/name)" in
			rg28xx-h) convert "$BOOTLOGO_MOUNT/bootlogo.bmp" -rotate 270 "$BOOTLOGO_MOUNT/bootlogo.bmp" ;;
		esac
	fi

	printf "Install complete\n"
	sync

	[ "$(GET_VAR "global" "settings/general/bgm")" -eq 2 ] && START_BGM
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
}

case "$MODE" in
	install) INSTALL ;;
	save) SAVE ;;
	*) USAGE ;;
esac
