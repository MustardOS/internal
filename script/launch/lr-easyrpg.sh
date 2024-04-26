#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')

if [ "$(echo $ROM | awk -F. '{print $NF}')" == "zip" ]; then
	/opt/muos/script/mux/track.sh "$NAME" retroarch -v -f -c \""/mnt/mmc/MUOS/retroarch/retroarch.cfg"\" -L \""/mnt/mmc/MUOS/core/$CORE"\" \""$ROM"\"
	rm -Rf "$ROM.save"
else
	ERPC=$(<"$ROM.cfg" sed 's/[[:space:]]*$//')

	if [ -d "$ROMPATH/.$NAME" ]; then
		SUBFOLDER=".$NAME"
	else
		SUBFOLDER="$NAME"
	fi
	/opt/muos/script/mux/track.sh "$NAME" retroarch -v -f -c \""/mnt/mmc/MUOS/retroarch/retroarch.cfg"\" -L \""/mnt/mmc/MUOS/core/easyrpg_libretro.so"\" \""$ROMPATH/$SUBFOLDER/$ERPC"\"
fi
