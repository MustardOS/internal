#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

EMUDIR="/mnt/mmc/MUOS/emulator/mupen64plus"

chmod +x $EMUDIR/mupen64plus
cd $EMUDIR || continue

fbset -fb /dev/fb0 -g 320 240 320 240 32

HOME="$EMUDIR" SDL_ASSERT=always_ignore nice --20 ./mupen64plus --corelib ./libmupen64plus.so.2.0.0 --configdir . "$ROM"

