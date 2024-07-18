#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

LOG_DATE="$(date +'[%Y-%m-%d]')"

# Move control.ini for ppsspp standalone
CONTROL_INI="$DC_STO_ROM_MOUNT/MUOS/emulator/ppsspp/.config/ppsspp/PSP/SYSTEM/controls.ini"
if [ ! -f "$CONTROL_INI" ]; then
	cp "$DEVICE_CONTROL_DIR/controls.ini" "$CONTROL_INI"
fi

# Move mupen64plus-rice.cfg for external mupen64plus
MP64RICE="$DC_STO_ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-rice.cfg"
if [ ! -f "$MP64RICE" ]; then
	cp "$DEVICE_CONTROL_DIR/mupen64plus-rice.cfg" "$MP64RICE"
fi

# Move mupen64plus-gl64.cfg for external mupen64plus
MP64GL64="$DC_STO_ROM_MOUNT/MUOS/emulator/mupen64plus/mupen64plus-gl64.cfg"
if [ ! -f "$MP64GL64" ]; then
	cp "$DEVICE_CONTROL_DIR/mupen64plus-gl64.cfg" "$MP64GL64"
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
