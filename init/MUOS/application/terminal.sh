#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")

export LD_LIBRARY_PATH=/usr/lib32
export SDL_HQ_SCALER="$SDL_SCALER"

TERM_DIR="$STORE_ROM/MUOS/application/terminal"
cd "$TERM_DIR"

HOME="$TERM_DIR" SDL_ASSERT=always_ignore ./terminal
