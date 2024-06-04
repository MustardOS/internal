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

echo "amiberry" > /tmp/fg_proc

EMUDIR="$STORE_ROM/MUOS/emulator/amiberry"

chmod +x "$EMUDIR"/amiberry
cd "$EMUDIR" || exit

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./amiberry "$ROM"

