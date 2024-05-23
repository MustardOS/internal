#!/bin/sh

RMP_LOG="/mnt/mmc/MUOS/log/device.log"
LOG_DATE="$(date +'[%Y-%m-%d]')"

# Restore device specific gamecontrollerdb.txt
GCDB_ARMHF="/usr/lib32/gamecontrollerdb.txt"
GCDB_AARCH64="/usr/lib/gamecontrollerdb.txt"
GCDB_28XX="/opt/muos/backup/gamecontroller/gamecontrollerdb_28xx.txt"
cp -f "GCDB_28XX" "GCDB_ARMHF"
cp -f "GCDB_28XX" "GCDB_AARCH64"

# Move RetroArch configurations to their rightful place
RA_CONF="/mnt/mmc/MUOS/retroarch/retroarch.cfg"
if [ ! -f "$RA_CONF" ]; then
    cp /opt/muos/backup/retroarch/rg28xx-retroarch.cfg "$RA_CONF"
fi

RA32_CONF="/mnt/mmc/MUOS/retroarch/retroarch32.cfg"
if [ ! -f "$RA32_CONF" ]; then
    cp /opt/muos/backup/retroarch/rg28xx-retroarch32.cfg "$RA32_CONF"
fi

# Move DraStic configuration
DRA_CONF="/mnt/mmc/MUOS/emulator/drastic/config/drastic.cfg"
cp -f "/mnt/mmc/MUOS/emulator/drastic/config/drastic_28xx.cfg" "$DRA_CONF"

# Move Mupen configuration to their rightful place
MUP_DEF="/mnt/mmc/MUOS/emulator/mupen64plus/mupen64plus.cfg"
MUP_RICE="/mnt/mmc/MUOS/emulator/mupen64plus/mupen64plus-rice.cfg"
if [ ! -f "$MUP_RICE" ]; then
    cp "/mnt/mmc/MUOS/emulator/mupen64plus/mupen64plus-rice-plus.cfg" "$MUP_RICE"
    # Set as initial default core
    cp "$MUP_RICE" "$MUP_DEF"
fi

MUP_GL64="/mnt/mmc/MUOS/emulator/mupen64plus/mupen64plus-gl64.cfg"
if [ ! -f "$MUP_GL64" ]; then
    cp "/mnt/mmc/MUOS/emulator/mupen64plus/mupen64plus-gl64-plus.cfg" "$MUP_GL64"
fi

# Define Nintendo 64 remap paths
MP64_RMP="/mnt/mmc/MUOS/info/config/remaps/Mupen64Plus-Next/Mupen64Plus-Next.rmp"

# Check for Mupen64Plus remap
MP64_DIR=$(dirname "$MP64_RMP")
if [ ! -d "$MP64_DIR" ]; then
    mkdir -p "$MP64_DIR"
fi

if [ ! -e "$MP64_RMP" ]; then
    cat <<EOF > "$MP64_RMP"
input_libretro_device_p1 = "1"
input_libretro_device_p2 = "1"
input_libretro_device_p3 = "1"
input_libretro_device_p4 = "1"
input_player1_analog_dpad_mode = "0"
input_player1_btn_down = "18"
input_player1_btn_left = "17"
input_player1_btn_right = "16"
input_player1_btn_up = "19"
input_player1_stk_l_x+ = "7"
input_player1_stk_l_x- = "6"
input_player1_stk_l_y+ = "5"
input_player1_stk_l_y- = "4"
input_player2_analog_dpad_mode = "0"
input_player3_analog_dpad_mode = "0"
input_player4_analog_dpad_mode = "0"
input_remap_port_p1 = "0"
input_remap_port_p2 = "1"
input_remap_port_p3 = "2"
input_remap_port_p4 = "3"
EOF
echo "$LOG_DATE File $MP64_RMP created. Set Mupen64Plus-Next controls for dpad only." >> "$RMP_LOG"
else
    echo "$LOG_DATE No file created. Remap existed at $MP64_RMP" >> "$RMP_LOG"
fi

