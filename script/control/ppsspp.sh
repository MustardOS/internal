#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE_PREFIX="rg tui"
for PREFIX in $DEVICE_PREFIX; do
	PPSSPP_SYS="/opt/muos/share/emulator/ppsspp/${PREFIX}/.config/ppsspp/PSP/SYSTEM"
	mkdir -p "$PPSSPP_SYS"

	PPSSPP_TYPE="controls ppsspp"
	for PT in $PPSSPP_TYPE; do
		PPSSPP_INI="${PPSSPP_SYS}/${PT}.ini"
		[ ! -f "$PPSSPP_INI" ] && cp "$DEVICE_CONTROL_DIR/ppsspp/${PREFIX}/${PT}.ini" "$PPSSPP_INI"
	done
done
