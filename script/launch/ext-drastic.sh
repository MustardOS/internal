#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

EMUDIR="/mnt/mmc/MUOS/emulator/drastic"

chmod +x $EMUDIR/drastic
cd $EMUDIR || continue

HOME="$EMUDIR" SDL_ASSERT=always_ignore nice --20 ./drastic "$ROM"

