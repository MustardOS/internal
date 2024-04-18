#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')

if [ -d "$ROMPATH/.$NAME" ]; then
	SUBFOLDER=".$NAME"
else
	SUBFOLDER="$NAME"
fi

SCVM="$ROMPATH/$SUBFOLDER/$NAME.scummvm"

cp "$ROMPATH/$NAME.scummvm" "$SCVM"

/opt/muos/script/mux/track.sh "$NAME" retroarch -f -c \""/mnt/mmc/MUOS/retroarch/retroarch.cfg"\" -L \""/mnt/mmc/MUOS/core/scummvm_libretro.so"\" \""$SCVM"\"

