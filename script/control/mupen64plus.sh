#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "$1" = "FORCE_COPY" ] && FORCE_COPY=1

MP64_DIR="$MUOS_SHARE_DIR/emulator/mupen64plus"

COPY_CONTROL() {
	SRC="$1"
	DST="$2"

	# Not every device ships every Mupen64Plus control file
	[ -f "$SRC" ] || return 0

	if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$DST" ]; then
		cp -f "$SRC" "$DST"
	fi
}

mkdir -p "$MP64_DIR/configs"

COPY_CONTROL "$DEVICE_CONTROL_DIR/mupen64plus-device.cfg" "$MP64_DIR/mupen64plus-device.cfg"
COPY_CONTROL "$DEVICE_CONTROL_DIR/Default-InputAutoCfg.ini" "$MP64_DIR/configs/Default-InputAutoCfg.ini"
