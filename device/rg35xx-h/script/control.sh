#!/bin/sh

. /opt/muos/script/system/parse.sh
DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

CONTROL_DIR="/opt/muos/device/$DEVICE/control"
ROM_MOUNT=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

RMP_LOG="/mnt/mmc/MUOS/log/device.log"
LOG_DATE="$(date +'[%Y-%m-%d]')"

# Restore device specific gamecontrollerdb.txt
for GCDB_DIR in "/usr/lib32" "/usr/lib"; do
	cp -f "$CONTROL_DIR/gamecontrollerdb.txt" "$GCDB_DIR/gamecontrollerdb.txt"
done

# Move RetroArch configurations
for RA_CONF in "retroarch.cfg" "retroarch32.cfg"; do
	DEST_CONF="/$ROM_MOUNT/MUOS/retroarch/$RA_CONF"
	if [ ! -f "$DEST_CONF" ]; then
		cp "$CONTROL_DIR/$RA_CONF" "$DEST_CONF"
	fi
done

# Move DraStic Steward config
DRSTU_JSON="/$ROM_MOUNT/MUOS/emulator/drastic-steward/resources/settings.json"

if [ ! -f "$DRSTU_JSON" ]; then
	cp -f "$CONTROL_DIR/drastic-steward.json" "$DRSTU_JSON"
fi

# Move DraStic configuration
cp -f "$CONTROL_DIR/drastic.cfg" "/$ROM_MOUNT/MUOS/emulator/drastic/config/drastic.cfg"

# Move Mupen configuration
MUP_DEF="/$ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus.cfg"
MUP_RICE="/$ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-rice.cfg"
if [ ! -f "$MUP_RICE" ]; then
	cp "/$ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-rice-plus.cfg" "$MUP_RICE"
	# Set as initial default core
	cp "$MUP_RICE" "$MUP_DEF"
fi

MUP_GL64="/$ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-gl64.cfg"
if [ ! -f "$MUP_GL64" ]; then
	cp "/$ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-gl64-plus.cfg" "$MUP_GL64"
fi

# Define Nintendo 64 remap paths
MP64_RMP="/$ROM_MOUNT/MUOS/info/config/remaps/Mupen64Plus-Next/Mupen64Plus-Next.rmp"

# Define Playstation remap paths
DUCK_RMP="/$ROM_MOUNT/MUOS/info/config/remaps/DuckStation/DuckStation.rmp"
PCSX_RMP="/$ROM_MOUNT/MUOS/info/config/remaps/PCSX-ReARMed/PCSX-ReARMed.rmp"
SWAN_RMP="/$ROM_MOUNT/MUOS/info/config/remaps/SwanStation/SwanStation.rmp"

# Check for DuckStation remap
DUCK_DIR=$(dirname "$DUCK_RMP")
if [ ! -d "$DUCK_DIR" ]; then
	mkdir -p "$DUCK_DIR"
fi

if [ ! -e "$DUCK_RMP" ]; then
	cat <<EOF > "$DUCK_RMP"
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
	echo "$LOG_DATE File $DUCK_RMP created. DualShock Enabled for DuckStation" >> "$RMP_LOG"
else
	echo "$LOG_DATE No file created. Remap existed at $DUCK_RMP" >> "$RMP_LOG"
fi

# Check for PCSX Remap
PCSX_DIR=$(dirname "$PCSX_RMP")
if [ ! -d "$PCSX_DIR" ]; then
	mkdir -p "$PCSX_DIR"
fi

if [ ! -e "$PCSX_RMP" ]; then
	cat <<EOF > "$PCSX_RMP"
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
	echo "$LOG_DATE File $PCSX_RMP created. DualShock Enabled for PCSX-ReARMed" >> "$RMP_LOG"
else
	echo "$LOG_DATE No file created. Remap existed at $PCSX_RMP" >> "$RMP_LOG"
fi

# Check for SwanStation Remap
SWAN_DIR=$(dirname "$SWAN_RMP")
if [ ! -d "$SWAN_DIR" ]; then
	mkdir -p "$SWAN_DIR"
fi

if [ ! -e "$SWAN_RMP" ]; then
	cat <<EOF > "$SWAN_RMP"
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
	echo "$LOG_DATE File $SWAN_RMP created. DualShock Enabled for SwanStation" >> "$RMP_LOG"
else
	echo "$LOG_DATE No file created. Remap existed at $SWAN_RMP" >> "$RMP_LOG"
fi

