#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/init/system.sh

RMP_LOG="/mnt/mmc/MUOS/log/device.log"
LOG_DATE="$(date +'[%Y-%m-%d]')"

# Move control.ini for ppsspp standalone
CONTROL_INI="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp/.config/ppsspp/PSP/SYSTEM/controls.ini"
if [ ! -f "$CONTROL_INI" ]; then
	cp "$DEVICE_CONTROL_DIR/ppsspp_controls.ini" "$CONTROL_INI"
fi

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
RA_CONF=/run/muos/storage/info/config/retroarch.cfg
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

# Define Playstation remap paths
DUCK_RMP=/run/muos/storage/info/config/remaps/DuckStation/DuckStation.rmp
PCSX_RMP=/run/muos/storage/info/config/remaps/PCSX-ReARMed/PCSX-ReARMed.rmp
SWAN_RMP=/run/muos/storage/info/config/remaps/SwanStation/SwanStation.rmp

# Check for DuckStation remap
DUCK_DIR=$(dirname "$DUCK_RMP")
if [ ! -d "$DUCK_DIR" ]; then
	mkdir -p "$DUCK_DIR"
fi

if [ ! -e "$DUCK_RMP" ]; then
	cat <<EOF >"$DUCK_RMP"
input_libretro_device_p1 = "5"
input_libretro_device_p2 = "1"
input_libretro_device_p3 = "1"
input_libretro_device_p4 = "1"
input_player1_analog_dpad_mode = "1"
input_player2_analog_dpad_mode = "0"
input_player3_analog_dpad_mode = "0"
input_player4_analog_dpad_mode = "0"
input_remap_port_p1 = "0"
input_remap_port_p2 = "1"
input_remap_port_p3 = "2"
input_remap_port_p4 = "3"
EOF
	echo "$LOG_DATE File $DUCK_RMP created. DualShock Enabled for DuckStation" >>"$RMP_LOG"
else
	echo "$LOG_DATE No file created. Remap existed at $DUCK_RMP" >>"$RMP_LOG"
fi

# Check for PCSX Remap
PCSX_DIR=$(dirname "$PCSX_RMP")
if [ ! -d "$PCSX_DIR" ]; then
	mkdir -p "$PCSX_DIR"
fi

if [ ! -e "$PCSX_RMP" ]; then
	cat <<EOF >"$PCSX_RMP"
input_libretro_device_p1 = "517"
input_libretro_device_p2 = "1"
input_libretro_device_p3 = "1"
input_libretro_device_p4 = "1"
input_player1_analog_dpad_mode = "0"
input_player2_analog_dpad_mode = "0"
input_player3_analog_dpad_mode = "0"
input_player4_analog_dpad_mode = "0"
input_remap_port_p1 = "0"
input_remap_port_p2 = "1"
input_remap_port_p3 = "2"
input_remap_port_p4 = "3"
EOF
	echo "$LOG_DATE File $PCSX_RMP created. DualShock Enabled for PCSX-ReARMed" >>"$RMP_LOG"
else
	echo "$LOG_DATE No file created. Remap existed at $PCSX_RMP" >>"$RMP_LOG"
fi

# Check for SwanStation Remap
SWAN_DIR=$(dirname "$SWAN_RMP")
if [ ! -d "$SWAN_DIR" ]; then
	mkdir -p "$SWAN_DIR"
fi

if [ ! -e "$SWAN_RMP" ]; then
	cat <<EOF >"$SWAN_RMP"
input_libretro_device_p1 = "261"
input_libretro_device_p2 = "1"
input_libretro_device_p3 = "1"
input_libretro_device_p4 = "1"
input_player1_analog_dpad_mode = "0"
input_player2_analog_dpad_mode = "0"
input_player3_analog_dpad_mode = "0"
input_player4_analog_dpad_mode = "0"
input_remap_port_p1 = "0"
input_remap_port_p2 = "1"
input_remap_port_p3 = "2"
input_remap_port_p4 = "3"
EOF
	echo "$LOG_DATE File $SWAN_RMP created. DualShock Enabled for SwanStation" >>"$RMP_LOG"
else
	echo "$LOG_DATE No file created. Remap existed at $SWAN_RMP" >>"$RMP_LOG"
fi

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
