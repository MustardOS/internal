#!/bin/sh

. /opt/muos/script/var/func.sh

RMP_LOG="/mnt/mmc/MUOS/log/psx.remap.log"
LOG_DATE="$(date +'[%Y-%m-%d]')"

REMAP_DIR="$MUOS_SHARE_DIR/info/config/remaps"

# Check for DuckStation remap
DUCK_RMP="${REMAP_DIR}/DuckStation/DuckStation.rmp"
mkdir -p "$(dirname "$DUCK_RMP")"

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
PCSX_RMP="${REMAP_DIR}/PCSX-ReARMed/PCSX-ReARMed.rmp"
mkdir -p "$(dirname "$PCSX_RMP")"

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
SWAN_RMP="${REMAP_DIR}/SwanStation/SwanStation.rmp"
mkdir -p "$(dirname "$SWAN_RMP")"

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
