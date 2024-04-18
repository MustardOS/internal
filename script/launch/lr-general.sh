#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

/opt/muos/script/mux/track.sh "$NAME" retroarch -f -c \""/mnt/mmc/MUOS/retroarch/retroarch.cfg"\" -L \""/mnt/mmc/MUOS/core/$CORE"\" \""$ROM"\"

