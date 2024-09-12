#!/bin/sh

. /opt/muos/script/var/func.sh

if [ "$1" = "?R" ] && [ "$(GET_VAR "global" "settings/advanced/random_theme")" -eq 1 ]; then
	THEME=$(find "/run/muos/storage/theme" -name '*.zip' | shuf -n 1)
else
	THEME="/run/muos/storage/theme/$1.zip"
fi

THEME_DIR="/run/muos/storage/theme"

BOOTLOGO_DEF="/opt/muos/device/$(GET_VAR "device" "board/name")/bootlogo.bmp"
BOOTLOGO_NEW="$THEME_DIR/active/image/bootlogo.bmp"

cp "$BOOTLOGO_DEF" "$(GET_VAR "device" "storage/boot/mount")/bootlogo.bmp"

while [ -d "$THEME_DIR/active" ]; do
	rm -rf "$THEME_DIR/active"
	sync
	sleep 1
done

unzip "$THEME" -d "$THEME_DIR/active"

DEV_BOARD=$(GET_VAR "device" "board/name")
case "$DEV_BOARD" in
	rg40xx*)
		RGBCONF_SCRIPT="/run/muos/storage/theme/active/rgb/rgbconf.sh"
		if [ -f "$RGBCONF_SCRIPT" ]; then
			"$RGBCONF_SCRIPT"
		else
			/opt/muos/device/"$DEV_BOARD"/script/led_control.sh 1 0 0 0 0 0 0 0
		fi
		;;
	*) ;;
esac

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
