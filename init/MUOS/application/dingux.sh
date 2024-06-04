#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")

export SDL_HQ_SCALER="$SDL_SCALER"
export SDL_GAMECONTROLLER="/usr/lib/gamecontrollerdb.txt"

DINGUX_DIR="/mnt/mmc/MUOS/application/dingux"

cd "$DINGUX_DIR" || exit

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "$SDL_GAMECONTROLLER") ./dingux --config "$DINGUX_DIR/dingux.cfg"
