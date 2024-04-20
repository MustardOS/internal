#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

EMUDIR="/mnt/mmc/MUOS/emulator/flycast"

chmod +x $EMUDIR/flycast
cd $EMUDIR || continue



HOME="$EMUDIR" SDL_ASSERT=always_ignore nice --20 ./flycast "$ROM"

