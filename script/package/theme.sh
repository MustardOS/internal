#!/bin/sh

. /opt/muos/script/var/func.sh

if [ "$1" = "?R" ] && [ "$(GET_VAR "global" "settings/advanced/random_theme")" -eq 1 ]; then
	THEME=$(find "/run/muos/storage/theme" -name '*.zip' | shuf -n 1)
else
	THEME="/run/muos/storage/theme/$1.zip"
fi

cp "/opt/muos/device/current/bootlogo.bmp" "$(GET_VAR "device" "storage/boot/mount")/bootlogo.bmp"

THEME_DIR="/run/muos/storage/theme"

while [ -d "$THEME_DIR/active" ]; do
	rm -rf "$THEME_DIR/active"
	sync
	sleep 1
done

unzip "$THEME" -d "$THEME_DIR/active"

THEME_NAME=$(basename "$THEME" .zip)
CLEANED_THEME_NAME=$(echo "$THEME_NAME" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
echo "$CLEANED_THEME_NAME" >"$THEME_DIR/active/theme_name.txt"

BOOTLOGO_NEW="$THEME_DIR/active/$(GET_VAR device mux/width)x$(GET_VAR device mux/height)/image/bootlogo.bmp"
[ ! -f "$BOOTLOGO_NEW" ] && BOOTLOGO_NEW="$THEME_DIR/active/image/bootlogo.bmp"

if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
	RGBCONF_SCRIPT="/run/muos/storage/theme/active/rgb/rgbconf.sh"
	if [ -f "$RGBCONF_SCRIPT" ]; then
		"$RGBCONF_SCRIPT"
	else
		/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
	fi
fi

if [ "$(GET_VAR "global" "settings/advanced/random_theme")" -eq 0 ]; then
	if [ -f "$BOOTLOGO_NEW" ]; then
		cp "$BOOTLOGO_NEW" "$(GET_VAR "device" "storage/boot/mount")/bootlogo.bmp"
		case "$(GET_VAR "device" "board/name")" in
			rg28xx) convert "$(GET_VAR "device" "storage/boot/mount")/bootlogo.bmp" -rotate 270 "$(GET_VAR "device" "storage/boot/mount")/bootlogo.bmp" ;;
			*) ;;
		esac
	fi
fi

sync
