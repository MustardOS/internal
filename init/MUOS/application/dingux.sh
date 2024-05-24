#!/bin/sh

# Check for RG28XX and rotate screen if found
if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
	export SDL_HQ_SCALER=1
fi

DINGUX_DIR="/opt/muos/app/dingux"

cd "$DINGUX_DIR" || exit

export LD_LIBRARY_PATH=/usr/lib32

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "$DINGUX_DIR/gamecontrollerdb.txt") ./dingux --config "$DINGUX_DIR/dingux.cfg"
