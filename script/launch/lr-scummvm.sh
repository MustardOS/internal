#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
	export SDL_HQ_SCALER=1
fi

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')

if [ -d "$ROMPATH/.$NAME" ]; then
	SUBFOLDER=".$NAME"
else
	SUBFOLDER="$NAME"
fi

SCVM="$ROMPATH/$SUBFOLDER/$NAME.scummvm"

cp "$ROMPATH/$NAME.scummvm" "$SCVM"

/opt/muos/script/mux/track.sh "$NAME" retroarch -v -f -c \""/mnt/mmc/MUOS/retroarch/retroarch.cfg"\" -L \""/mnt/mmc/MUOS/core/scummvm_libretro.so"\" \""$SCVM"\"

