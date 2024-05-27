#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")

export SDL_HQ_SCALER="$SDL_SCALER"

DINGUX_DIR="$(pwd)/dingux"

cd "$DINGUX_DIR" || exit

export LD_LIBRARY_PATH=/usr/lib32

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "$DINGUX_DIR/gamecontrollerdb.txt") ./dingux --config "$DINGUX_DIR/dingux.cfg"
