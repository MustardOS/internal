#!/bin/sh

. /opt/muos/script/var/func.sh

PPSSPP_SYS="$MUOS_SHARE_DIR/emulator/ppsspp/.config/ppsspp/PSP/SYSTEM"
mkdir -p "$PPSSPP_SYS"

PPSSPP_TYPE="controls ppsspp"
for PT in $PPSSPP_TYPE; do
	PPSSPP_INI="${PPSSPP_SYS}/${PT}.ini"
	[ ! -f "$PPSSPP_INI" ] && cp "$DEVICE_CONTROL_DIR/ppsspp/${PT}.ini" "$PPSSPP_INI"
done
