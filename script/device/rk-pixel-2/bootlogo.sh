#!/bin/sh

. /opt/muos/script/var/log.sh

# This U-Boot only ever draws logo.bmp from the boot partition, so the theme logo is copied over it
BOOT_MOUNT=$(GET_VAR "device" "storage/boot/mount")
LOGO="$BOOT_MOUNT/logo.bmp"
BACKUP="$BOOT_MOUNT/logo.orig.bmp"
LOGO_TMP="/tmp/rk_bootlogo_$$.bmp"

APPLY() {
	SRC=$1
	[ -f "$SRC" ] || {
		LOG_ERROR "$0" 0 "BOOTLOGO" "$(printf "No such image: %s" "$SRC")"
		return 1
	}

	SCREEN_W=$(GET_VAR "device" "screen/internal/width")
	SCREEN_H=$(GET_VAR "device" "screen/internal/height")
	[ -n "$SCREEN_W" ] && [ -n "$SCREEN_H" ] || return 1

	# The U-Boot BMP reader only handles plain 24-bit images at the panel size
	magick "${SRC}[0]" -resize "${SCREEN_W}x${SCREEN_H}!" -alpha off -type TrueColor BMP3:"$LOGO_TMP" || {
		LOG_ERROR "$0" 0 "BOOTLOGO" "Unable to convert the boot logo"
		rm -f "$LOGO_TMP"
		return 1
	}

	[ -f "$LOGO" ] && [ ! -f "$BACKUP" ] && cp -f "$LOGO" "$BACKUP"

	if ! cp -f "$LOGO_TMP" "$LOGO"; then
		LOG_ERROR "$0" 0 "BOOTLOGO" "Unable to write the boot logo"
		rm -f "$LOGO_TMP"
		return 1
	fi

	sync
	rm -f "$LOGO_TMP"

	LOG_INFO "$0" 0 "BOOTLOGO" "Boot logo written to logo.bmp"
	return 0
}

RESTORE() {
	[ -f "$BACKUP" ] || return 0
	cp -f "$BACKUP" "$LOGO" && sync
}

case "$1" in
	apply) APPLY "$2" ;;
	restore) RESTORE ;;
	*)
		printf 'Usage: %s apply IMAGE | restore\n' "$0" >&2
		exit 1
		;;
esac
