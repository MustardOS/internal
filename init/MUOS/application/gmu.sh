#!/bin/sh

GMU_DIR="$(pwd)/gmu"
GPTOKEYB="/mnt/mmc/MUOS/emulator/gptokeyb/gptokeyb2"
cd "$GMU_DIR" || exit

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib32/gamecontrollerdb.txt"
export LD_LIBRARY_PATH=/usr/lib32

$GPTOKEYB "gmu" -c "$GMU_DIR/gmu.gptk" &
SDL_ASSERT=always_ignore $SDL_GAMECONTROLLERCONFIG ./gmu -d "$GMU_DIR" -c "$GMU_DIR/gmu.conf"

kill -9 $(pidof gptokeyb2)