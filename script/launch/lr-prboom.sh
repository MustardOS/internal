#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")
SDL_ROTATE=$(parse_ini "$DEVICE_CONFIG" "sdl" "rotation")
SDL_BLITTER=$(parse_ini "$DEVICE_CONFIG" "sdl" "blitter_disabled")

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

export SDL_HQ_SCALER="$SDL_SCALER"
export SDL_ROTATION="$SDL_ROTATE"
export SDL_BLITTER_DISABLED="$SDL_BLITTER"

echo "retroarch" > /tmp/fg_proc

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')

mkdir -p "$ROMPATH/.$NAME"

PRBC="$ROMPATH/.$NAME/prboom.cfg"

# Compensate for Windows wild cuntery
dos2unix -n "$ROMPATH/$NAME.doom" "$ROMPATH/$NAME.doom"

IWAD=$(awk -F'"' '/parentwad/ {print $2}' "$ROMPATH/$NAME.doom")

cp -f "$ROMPATH/$NAME.doom" "$PRBC"
cp -f "$STORE_ROM/MUOS/bios/prboom.wad" "$ROMPATH/.$NAME/prboom.wad"
cp -f "$ROMPATH/.IWAD/$IWAD" "$ROMPATH/.$NAME/$IWAD"

retroarch -v -f -c "$STORE_ROM/MUOS/retroarch/retroarch.cfg" -L "$STORE_ROM/MUOS/core/prboom_libretro.so" "$ROMPATH/.$NAME/$IWAD"

