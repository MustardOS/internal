#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')

mkdir -p "$ROMPATH/.$NAME"

PRBC="$ROMPATH/.$NAME/prboom.cfg"
IWAD=$(awk -F'"' '/parentwad/ {print $2}' "$ROMPATH/$NAME.doom")

cp -f "$ROMPATH/$NAME.doom" "$PRBC"
cp -f /mnt/mmc/MUOS/bios/prboom.wad "$ROMPATH/.$NAME/prboom.wad"
cp -f "$ROMPATH/.IWAD/$IWAD" "$ROMPATH/.$NAME/$IWAD"

/opt/muos/script/mux/track.sh "$NAME" retroarch -f -c \""/mnt/mmc/MUOS/retroarch/retroarch.cfg"\" -L \""/mnt/mmc/MUOS/core/prboom_libretro.so"\" \""$ROMPATH/.$NAME/$IWAD"\"

