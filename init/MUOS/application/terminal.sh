#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")

# muOS v11 compatibility
if [ -d "/usr/lib32" ]; then
    export LD_LIBRARY_PATH=/usr/lib32
fi

export SDL_HQ_SCALER="$SDL_SCALER"

TERM_DIR="$(pwd)/terminal"
cd "$TERM_DIR"

HOME="$TERM_DIR" SDL_ASSERT=always_ignore ./terminal

