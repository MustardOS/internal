#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "$1" = "FORCE_COPY" ] && FORCE_COPY=1

RA_CONF="$MUOS_SHARE_DIR/info/config/retroarch.cfg"
RA_DEFAULT="$MUOS_SHARE_DIR/emulator/retroarch/retroarch.default.cfg"

# Set device-specific overlays
# Automatically process all files in the ra-config directory if it exists
RA_CONFIG_DIR="$MUOS_SHARE_DIR/info/config"
DEVICE_CONFIG_DIR="$DEVICE_CONTROL_DIR/ra-config"

BOARD_NAME="$(GET_VAR "device" "board/name")"

if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$RA_CONF" ]; then
	cp -f "$RA_DEFAULT" "$RA_CONF"
fi

if [ -d "$DEVICE_CONFIG_DIR" ]; then
	for DEVICE_CFG in "$DEVICE_CONFIG_DIR"/*.cfg; do
		[ -f "$DEVICE_CFG" ] || continue

		SYSTEM="$(basename "$DEVICE_CFG" .cfg)"
		SYS_DIR="$RA_CONFIG_DIR/$SYSTEM"
		CFG="$SYS_DIR/$SYSTEM.cfg"
		BACKUP_CFG="$CFG.$BOARD_NAME"

		mkdir -p "$SYS_DIR"

		if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$BACKUP_CFG" ]; then
			[ -f "$CFG" ] && cp -f "$CFG" "$BACKUP_CFG"
			cp -f "$DEVICE_CFG" "$CFG"
		fi
	done
fi

GLOBAL_SHADER="$RA_CONFIG_DIR/global.glslp"

if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$GLOBAL_SHADER" ]; then
	cp -f "$DEVICE_CONTROL_DIR/global.glslp" "$GLOBAL_SHADER"
fi
