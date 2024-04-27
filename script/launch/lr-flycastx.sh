#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root
export LD_LIBRARY_PATH=/usr/lib32

if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
	export SDL_HQ_SCALER=1
fi

/opt/muos/script/mux/track.sh "$NAME" retroarch32 -v -f -c \""/mnt/mmc/MUOS/retroarch/retroarch32.cfg"\" -L \""/mnt/mmc/MUOS/core32/$CORE"\" \""$ROM"\"
