#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

/opt/muos/script/mux/track.sh "$NAME" retroarch -v -f -c \""/mnt/mmc/MUOS/retroarch/retroarch.cfg"\" -L \""/mnt/mmc/MUOS/core/$CORE"\" \""$ROM"\"
