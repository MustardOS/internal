#!/bin/sh

. /opt/muos/script/var/func.sh

# Move RetroArch configuration
RA_CONF="$MUOS_SHARE_DIR/info/config/retroarch.cfg"
[ ! -f "$RA_CONF" ] && cp "$MUOS_SHARE_DIR/emulator/retroarch/retroarch.default.cfg" "$RA_CONF"

# Set device-specific overlays
# Automatically process all files in the ra-config directory if it exists
RA_CONFIG_DIR="$MUOS_SHARE_DIR/info/config"
DEVICE_CONFIG_DIR="$DEVICE_CONTROL_DIR/ra-config"

if [ -d "$DEVICE_CONFIG_DIR" ]; then
	for DEVICE_CFG in "$DEVICE_CONFIG_DIR"/*.cfg; do
		[ -f "$DEVICE_CFG" ] || continue

		SYSTEM=$(basename "$DEVICE_CFG" .cfg)
		CFG="$RA_CONFIG_DIR/$SYSTEM/$SYSTEM.cfg"
		BACKUP_CFG="$CFG.$(GET_VAR "device" "board/name")"

		if [ ! -f "$BACKUP_CFG" ]; then
			cp -f "$CFG" "$BACKUP_CFG"
			cp -f "$DEVICE_CFG" "$CFG"
		fi
	done
fi

# Copy the RetroArch global shader if it doesn't already exist
[ ! -f "$RA_CONFIG_DIR/global.glslp" ] && cp -f "$DEVICE_CONTROL_DIR/global.glslp" "$RA_CONFIG_DIR/global.glslp"
