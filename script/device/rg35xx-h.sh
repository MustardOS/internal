#!/bin/sh

RMP_LOG="/mnt/mmc/MUOS/log/device.log"
LOG_DATE="$(date +'[%Y-%m-%d]')"

# Move RetroArch configurations to their rightful place
RA_CONF="/mnt/mmc/MUOS/retroarch/retroarch.cfg"
if [ ! -f "$RA_CONF" ]; then
    cp /opt/muos/backup/retroarch/rg35xx-plush-retroarch.cfg "$RA_CONF"
fi

RA32_CONF="/mnt/mmc/MUOS/retroarch/retroarch32.cfg"
if [ ! -f "$RA32_CONF" ]; then
    cp /opt/muos/backup/retroarch/rg35xx-plush-retroarch32.cfg "$RA32_CONF"
fi

# Define Playstation remap paths
DUCK_RMP="/mnt/mmc/MUOS/info/config/remaps/DuckStation/DuckStation.rmp"
PCSX_RMP="/mnt/mmc/MUOS/info/config/remaps/PCSX-ReARMed/PCSX-ReARMed.rmp"
SWAN_RMP="/mnt/mmc/MUOS/info/config/remaps/SwanStation/SwanStation.rmp"

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

