#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export LD_LIBRARY_PATH=/usr/lib32

/opt/muos/script/mux/track.sh "$NAME" retroarch32 -f -c \""/mnt/mmc/MUOS/retroarch/retroarch32.cfg"\" -L \""/mnt/mmc/MUOS/core32/$CORE"\" \""$ROM"\"
