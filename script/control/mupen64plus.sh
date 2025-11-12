#!/bin/sh

. /opt/muos/script/var/func.sh

MP64_DIR="$MUOS_SHARE_DIR/emulator/mupen64plus"

mkdir -p "$MP64_DIR"
MP64_TARGET="${MP64_DIR}/mupen64plus-device.cfg"
[ ! -f "$MP64_TARGET" ] && cp "$DEVICE_CONTROL_DIR/mupen64plus-device.cfg" "$MP64_TARGET"

mkdir -p "${MP64_DIR}/configs"
SRC_INI="${DEVICE_CONTROL_DIR}/Default-InputAutoCfg.ini"
DST_INI="${MP64_DIR}/configs/Default-InputAutoCfg.ini"
[ ! -f "$DST_INI" ] && cp "$SRC_INI" "$DST_INI"
