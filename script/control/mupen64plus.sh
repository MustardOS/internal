#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "$1" = "FORCE_COPY" ] && FORCE_COPY=1

MP64_DIR="$MUOS_SHARE_DIR/emulator/mupen64plus"

mkdir -p "$MP64_DIR"
MP64_TARGET="${MP64_DIR}/mupen64plus-device.cfg"

if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$MP64_TARGET" ]; then
	cp -f "$DEVICE_CONTROL_DIR/mupen64plus-device.cfg" "$MP64_TARGET"
fi

mkdir -p "${MP64_DIR}/configs"
SRC_INI="${DEVICE_CONTROL_DIR}/Default-InputAutoCfg.ini"
DST_INI="${MP64_DIR}/configs/Default-InputAutoCfg.ini"

if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$DST_INI" ]; then
	cp -f "$SRC_INI" "$DST_INI"
fi
