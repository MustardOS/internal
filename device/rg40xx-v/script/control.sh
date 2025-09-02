#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE_PREFIX="rg tui"
for PREFIX in $DEVICE_PREFIX; do
	PPSSPP_DIR="/opt/muos/share/emulator/ppsspp"

	PPSSPP_CONTROL_INI="${PPSSPP_DIR}/${PREFIX}/.config/ppsspp/PSP/SYSTEM/controls.ini"
	PPSSPP_SYSTEM_INI="${PPSSPP_DIR}/${PREFIX}/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

	mkdir -p "${PPSSPP_DIR}/${PREFIX}/.config/ppsspp/PSP/SYSTEM"
	if [ ! -f "$PPSSPP_CONTROL_INI" ]; then
		cp "$DEVICE_CONTROL_DIR/ppsspp/${PREFIX}/controls.ini" "$PPSSPP_CONTROL_INI"
	fi
	if [ ! -f "$PPSSPP_SYSTEM_INI" ]; then
		cp "$DEVICE_CONTROL_DIR/ppsspp/${PREFIX}/ppsspp.ini" "$PPSSPP_SYSTEM_INI"
	fi
done

# Move mupen64plus-rice.cfg for external mupen64plus
MP64RICE="/opt/muos/share/emulator/mupen64plus/mupen64plus-rice.cfg"
if [ ! -f "$MP64RICE" ]; then
	mkdir -p "/opt/muos/share/emulator/mupen64plus"
	cp "$DEVICE_CONTROL_DIR/mupen64plus-rice.cfg" "$MP64RICE"
fi

# Move mupen64plus-gl64.cfg for external mupen64plus
MP64GL64="/opt/muos/share/emulator/mupen64plus/mupen64plus-gl64.cfg"
if [ ! -f "$MP64GL64" ]; then
	mkdir -p "/opt/muos/share/emulator/mupen64plus"
	cp "$DEVICE_CONTROL_DIR/mupen64plus-gl64.cfg" "$MP64GL64"
fi

# Move RetroArch configuration
RA_CONF="/opt/muos/share/info/config/retroarch.cfg"
if [ ! -f "$RA_CONF" ]; then
	cp /opt/muos/share/emulator/retroarch/retroarch.default.cfg "$RA_CONF"
fi

# Move gamecontrollerdb files - overwrite existing for users protection!
GCDB_STORE="/opt/muos/share/info/gamecontrollerdb"
[ -d "$GCDB_STORE" ] || mkdir -p "$GCDB_STORE"
cp -f "$DEVICE_CONTROL_DIR/gamecontrollerdb"/*.txt "$GCDB_STORE"/
# Purge anything with the 'system' reserved name!
rm -f "$GCDB_STORE/system.txt"
touch "$GCDB_STORE/system.txt"

# Move Drastic trngaje config
DRASTIC_T_JSON="/opt/muos/share/emulator/drastic-trngaje/resources/settings.json"
DRASTIC_T_CFG="/opt/muos/share/emulator/drastic-trngaje/config/drastic.cfg"
if [ ! -f "$DRASTIC_T_JSON" ]; then
	mkdir -p "/opt/muos/share/emulator/drastic-trngaje/resources"
	cp -f "$DEVICE_CONTROL_DIR/drastic-trngaje/settings.json" "$DRASTIC_T_JSON"
fi
if [ ! -f "$DRASTIC_T_CFG" ]; then
	mkdir -p "/opt/muos/share/emulator/drastic-trngaje/config"
	cp -f "$DEVICE_CONTROL_DIR/drastic-trngaje/drastic.cfg" "$DRASTIC_T_CFG"
fi

# Move DraStic Legacy config
DRASTIC_CFG="/opt/muos/share/emulator/drastic-legacy/config/drastic.cfg"
if [ ! -f "$DRASTIC_CFG" ]; then
	mkdir -p "/opt/muos/share/emulator/drastic-legacy/config"
	cp -f "$DEVICE_CONTROL_DIR/drastic.cfg" "$DRASTIC_CFG"
fi

# Move YabaSanshiro config
YABASANSHIRO="/opt/muos/share/emulator/yabasanshiro/.emulationstation/es_temporaryinput.cfg"
if [ ! -f "$YABASANSHIRO" ]; then
	mkdir -p "/opt/muos/share/emulator/yabasanshiro/.emulationstation"
	cp "$DEVICE_CONTROL_DIR/yabasanshiro/es_temporaryinput.cfg" "$YABASANSHIRO"
fi

# Move OpenBOR config
for file in "$DEVICE_CONTROL_DIR/openbor/"*.ini; do
	if [ ! -f "/opt/muos/share/emulator/openbor/userdata/system/configs/openbor/$(basename "$file")" ]; then
		mkdir -p "/opt/muos/share/emulator/openbor/userdata/system/configs/openbor/"
		cp "$file" "/opt/muos/share/emulator/openbor/userdata/system/configs/openbor/"
	fi
done

# Set device-specific overlays
# Automatically process all files in the ra-config directory if it exists
RA_CONFIG_DIR="/opt/muos/share/info/config"
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

# Copy Device Specific Deeplay-keys.cfg udev autoconfig
RA_AUTO="/opt/muos/share/emulator/retroarch/autoconfig/udev/Deeplay-keys.cfg"
if [ -f "$RA_AUTO" ]; then
	rm -f "$RA_AUTO"
	cp "$DEVICE_CONTROL_DIR/Deeplay-keys.cfg" "$RA_AUTO"
fi
