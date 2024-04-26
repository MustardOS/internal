#!/bin/sh

DINGUX_DIR="/opt/muos/app/dingux"

cd "$DINGUX_DIR" || exit

export LD_LIBRARY_PATH=/usr/lib32

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "$DINGUX_DIR/gamecontrollerdb.txt") ./dingux --config "$DINGUX_DIR/dingux.cfg"
