#!/bin/sh

. /opt/muos/script/var/func.sh

if [ "$1" = "?R" ] && [ "$(GET_VAR "global" "settings/advanced/random_theme")" -eq 1 ]; then
	THEME=$(find "$(GET_VAR "global" "storage/theme")/MUOS/theme" -name '*.zip' | shuf -n 1)
else
	THEME="$(GET_VAR "global" "storage/theme")/MUOS/theme/$1.zip"
fi

THEME_DIR="$(GET_VAR "global" "storage/theme")/MUOS/theme"

BOOTLOGO_DEF="/opt/muos/device/$(GET_VAR "device" "board/name")/bootlogo.bmp"
BOOTLOGO_NEW="$THEME_DIR/active/image/bootlogo.bmp"

cp "$BOOTLOGO_DEF" "$(GET_VAR "device" "storage/boot/mount")/bootlogo.bmp"

while [ -d "$THEME_DIR/active" ]; do
	rm -rf "$THEME_DIR/active"
	sync
	sleep 1
done

unzip "$THEME" -d "$THEME_DIR/active"

if [ "$(GET_VAR "global" "settings/advanced/random_theme")" -eq 0 ]; then
	if [ -f "$BOOTLOGO_NEW" ]; then
		cp "$BOOTLOGO_NEW" "$(GET_VAR "device" "storage/boot/mount")/bootlogo.bmp"
		case "$(GET_VAR "device" "board/name")" in
			RG28XX)
				convert "$(GET_VAR "device" "storage/boot/mount")/bootlogo.bmp" -rotate 270 "$(GET_VAR "device" "storage/boot/mount")/bootlogo.bmp"
				;;
			*)
				# No conversion required
				;;
		esac
	fi
fi

sync
