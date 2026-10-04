#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "${1:-}" = "FORCE_COPY" ] && FORCE_COPY=1

OBOR_DIR="$MUOS_SHARE_DIR/emulator/openbor/userdata/system/configs/openbor"

mkdir -p "$OBOR_DIR"
for BOR_INI in "$DEVICE_CONTROL_DIR/openbor/"*.ini; do
	[ -f "$BOR_INI" ] || continue
	BOR_TARGET="$OBOR_DIR/${BOR_INI##*/}"
	if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$BOR_TARGET" ]; then
		cp -f "$BOR_INI" "$BOR_TARGET" || exit 1
	fi
done
