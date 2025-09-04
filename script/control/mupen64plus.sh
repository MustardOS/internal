#!/bin/sh

. /opt/muos/script/var/func.sh

MP64_DIR="/opt/muos/share/emulator/mupen64plus"

MP64_TYPE="rice gl64"
for MP64 in $MP64_TYPE; do
	mkdir -p "${MP64_DIR}"
	MP64_TARGET="${MP64_DIR}/mupen64plus-${MP64}.cfg"

	[ ! -f "$MP64_TARGET" ] && cp "$DEVICE_CONTROL_DIR/mupen64plus-${MP64}.cfg" "$MP64_TARGET"
done
