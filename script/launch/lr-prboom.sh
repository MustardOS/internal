#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

echo "retroarch" > /tmp/fg_proc

if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
	export SDL_HQ_SCALER=1
fi

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')

mkdir -p "$ROMPATH/.$NAME"

PRBC="$ROMPATH/.$NAME/prboom.cfg"

# Compensate for Windows wild cuntery
dos2unix -n "$ROMPATH/$NAME.doom" "$ROMPATH/$NAME.doom"

IWAD=$(awk -F'"' '/parentwad/ {print $2}' "$ROMPATH/$NAME.doom")

cp -f "$ROMPATH/$NAME.doom" "$PRBC"
cp -f /mnt/mmc/MUOS/bios/prboom.wad "$ROMPATH/.$NAME/prboom.wad"
cp -f "$ROMPATH/.IWAD/$IWAD" "$ROMPATH/.$NAME/$IWAD"

retroarch -v -f -c "/mnt/mmc/MUOS/retroarch/retroarch.cfg" -L "/mnt/mmc/MUOS/core/prboom_libretro.so" "$ROMPATH/.$NAME/$IWAD"

