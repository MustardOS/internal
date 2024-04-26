#!/bin/sh

GMU_DIR="/opt/muos/app/gmu"

cd "$GMU_DIR" || exit

export LD_LIBRARY_PATH=/usr/lib32

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "$GMU_DIR/gamecontrollerdb.txt") ./gmu -d "$GMU_DIR" -c "$GMU_DIR/gmu.conf"

