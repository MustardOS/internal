#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_DATE="$(date +'[%Y-%m-%d]')"

# Set ppsspp-sa root directory
PPSSPP_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp"

# Move configs for ppsspp-sa
DEVICE_PREFIX="rg tui"
for PREFIX in $DEVICE_PREFIX; do
	PPSSPP_CONTROL_INI="${PPSSPP_DIR}/${PREFIX}/.config/ppsspp/PSP/SYSTEM/controls.ini"
	PPSSPP_SYSTEM_INI="${PPSSPP_DIR}/${PREFIX}/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

	if [ ! -f "$PPSSPP_CONTROL_INI" ]; then
		cp "$DEVICE_CONTROL_DIR/ppsspp/${PREFIX}/controls.ini" "$PPSSPP_CONTROL_INI"
	fi
	if [ ! -f "$PPSSPP_SYSTEM_INI" ]; then
		cp "$DEVICE_CONTROL_DIR/ppsspp/${PREFIX}/ppsspp.ini" "$PPSSPP_SYSTEM_INI"
	fi
done

# Move mupen64plus-rice.cfg for external mupen64plus
MP64RICE="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/mupen64plus/mupen64plus-rice.cfg"
if [ ! -f "$MP64RICE" ]; then
	cp "$DEVICE_CONTROL_DIR/mupen64plus-rice.cfg" "$MP64RICE"
fi

# Move mupen64plus-gl64.cfg for external mupen64plus
MP64GL64="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/mupen64plus/mupen64plus-gl64.cfg"
if [ ! -f "$MP64GL64" ]; then
	cp "$DEVICE_CONTROL_DIR/mupen64plus-gl64.cfg" "$MP64GL64"
fi

# Move RetroArch configuration
RA_CONF="/run/muos/storage/info/config/retroarch.cfg"
if [ ! -f "$RA_CONF" ]; then
	cp /run/muos/storage/retroarch/retroarch.default.cfg "$RA_CONF"
fi

# Move Drastic trngaje config
DRASTIC_T_JSON="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic-trngaje/resources/settings.json"
DRASTIC_T_CFG="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic-trngaje/config/drastic.cfg"
if [ ! -f "$DRASTIC_T_JSON" ]; then
	cp -f "$DEVICE_CONTROL_DIR/drastic-trngaje/settings.json" "$DRASTIC_T_JSON"
fi
if [ ! -f "$DRASTIC_T_CFG" ]; then
	cp -f "$DEVICE_CONTROL_DIR/drastic-trngaje/drastic.cfg" "$DRASTIC_T_CFG"
fi

# Move DraStic Legacy config
DRASTIC_CFG="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/drastic-legacy/config/drastic.cfg"
if [ ! -f "$DRASTIC_CFG" ]; then
	cp -f "$DEVICE_CONTROL_DIR/drastic.cfg" "$DRASTIC_CFG"
fi

# Move YabaSanshiro config
YABASANSHIRO="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/yabasanshiro/.emulationstation/es_temporaryinput.cfg"
if [ ! -f "$YABASANSHIRO" ]; then
	cp "$DEVICE_CONTROL_DIR/yabasanshiro/es_temporaryinput.cfg" "$YABASANSHIRO"
fi

# Move OpenBOR config
for file in "$DEVICE_CONTROL_DIR/openbor/"*.ini; do
	if [ ! -f "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/openbor/userdata/system/configs/openbor/$(basename "$file")" ]; then
		cp "$file" "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/openbor/userdata/system/configs/openbor/"
	fi
done

# Set device-specific overlays
# Automatically process all files in the ra-config directory if it exists

RA_CONFIG_DIR="/run/muos/storage/info/config"
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

# Copy Device Specific Deeplay-keys.cfg udev autoconfig
RA_AUTO="/run/muos/storage/retroarch/autoconfig/udev/Deeplay-keys.cfg"
if [ -f "$RA_AUTO" ]; then
	rm -f "$RA_AUTO"
	cp "$DEVICE_CONTROL_DIR/Deeplay-keys.cfg" "$RA_AUTO"
fi
