#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")

NAME=$1
CORE=$2
ROM=$3

export HOME=/root
export SDL_HQ_SCALER="$SDL_SCALER"
export LD_LIBRARY_PATH=/usr/lib32

echo "retroarch32" > /tmp/fg_proc

retroarch32 -v -f -c "$STORE_ROM/MUOS/retroarch/retroarch32.cfg" -L "$STORE_ROM/MUOS/core32/$CORE" "$ROM"

