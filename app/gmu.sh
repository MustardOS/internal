#!/bin/sh

GMU_DIR="/opt/muos/app/gmu"

cd "$GMU_DIR" || exit

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "$GMU_DIR/gamecontrollerdb.txt") ./gmu -d "$GMU_DIR" -c "$GMU_DIR/gmu.conf"

