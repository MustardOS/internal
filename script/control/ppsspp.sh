#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "$1" = "FORCE_COPY" ] && FORCE_COPY=1

PPSSPP_SYS="$MUOS_SHARE_DIR/emulator/ppsspp/.config/ppsspp/PSP/SYSTEM"
PPSSPP_SRC="$DEVICE_CONTROL_DIR/ppsspp"

mkdir -p "$PPSSPP_SYS"

for PT in controls ppsspp; do
	SRC="${PPSSPP_SRC}/${PT}.ini"
	DST="${PPSSPP_SYS}/${PT}.ini"

	[ -f "$SRC" ] || continue

	if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$DST" ]; then
		cp -f "$SRC" "$DST"
	fi
done
