#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

EMUDIR="/mnt/mmc/MUOS/emulator/amiberry"

chmod +x $EMUDIR/amiberry
cd $EMUDIR || continue

HOME="$EMUDIR" SDL_ASSERT=always_ignore nice --20 ./amiberry "$ROM"

