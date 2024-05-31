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

echo "drastic" > /tmp/fg_proc

EMUDIR="/$STORE_ROM/MUOS/emulator/drastic"

chmod +x "$EMUDIR"/drastic
cd "$EMUDIR" || exit

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./drastic "$ROM"

