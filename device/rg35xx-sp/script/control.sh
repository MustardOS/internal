#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

RMP_LOG="/mnt/mmc/MUOS/log/device.log"
LOG_DATE="$(date +'[%Y-%m-%d]')"

# Move control.ini for ppsspp standalone
CONTROL_INI="$DC_STO_ROM_MOUNT/MUOS/emulator/ppsspp/.config/ppsspp/PSP/SYSTEM/controls.ini"
if [ ! -f "$CONTROL_INI" ]; then
	cp "$DEVICE_CONTROL_DIR/controls.ini" "$CONTROL_INI"
fi

# Move RetroArch configurations
RA_CONF="$DC_STO_ROM_MOUNT/MUOS/retroarch/retroarch.cfg"
if [ ! -f "$RA_CONF" ]; then
	cp "$DEVICE_CONTROL_DIR/retroarch.cfg" "$RA_CONF"
fi

# Move DraStic Steward config
DRSTU_JSON="$DC_STO_ROM_MOUNT/MUOS/emulator/drastic-steward/resources/settings.json"
if [ ! -f "$DRSTU_JSON" ]; then
	cp -f "$DEVICE_CONTROL_DIR/drastic-steward.json" "$DRSTU_JSON"
fi

# Move DraStic configuration
cp -f "$DEVICE_CONTROL_DIR/drastic.cfg" "$DC_STO_ROM_MOUNT/MUOS/emulator/drastic/config/drastic.cfg"

# Move Mupen configuration
MUP_DEF="$DC_STO_ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus.cfg"
MUP_RICE="$DC_STO_ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-rice.cfg"
if [ ! -f "$MUP_RICE" ]; then
	cp "$DC_STO_ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-rice-plus.cfg" "$MUP_RICE"
	# Set as initial default core
	cp "$MUP_RICE" "$MUP_DEF"
fi

MUP_GL64="$DC_STO_ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-gl64.cfg"
if [ ! -f "$MUP_GL64" ]; then
	cp "$DC_STO_ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-gl64-plus.cfg" "$MUP_GL64"
fi

# Define Nintendo 64 remap paths
MP64_RMP="$DC_STO_ROM_MOUNT/MUOS/info/config/remaps/Mupen64Plus-Next/Mupen64Plus-Next.rmp"

# Check for Mupen64Plus remap
MP64_DIR=$(dirname "$MP64_RMP")
if [ ! -d "$MP64_DIR" ]; then
	mkdir -p "$MP64_DIR"
fi

if [ ! -e "$MP64_RMP" ]; then
	cat <<EOF >"$MP64_RMP"
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
	echo "$LOG_DATE File $MP64_RMP created. Set Mupen64Plus-Next controls for dpad only." >>"$RMP_LOG"
else
	echo "$LOG_DATE No file created. Remap existed at $MP64_RMP" >>"$RMP_LOG"
fi

# Set GBA SP Overlay as default in gpSP / mGBA
GP_CFG="/$DC_STO_ROM_MOUNT/MUOS/info/config/gpSP/gpSP.cfg"
if [ ! -f "$GP_CFG.bak" ]; then
	cp "$GP_CFG" "$GP_CFG.bak"
	cp -f "$DEVICE_CONTROL_DIR/gpSP.cfg" "$GP_CFG"
fi

MG_CFG="/$DC_STO_ROM_MOUNT/MUOS/info/config/mGBA/mGBA.cfg"
if [ ! -f "$MG_CFG.bak" ]; then
	cp "$MG_CFG" "$MG_CFG.bak"
	cp -f "$DEVICE_CONTROL_DIR/mGBA.cfg" "$MG_CFG"
fi
