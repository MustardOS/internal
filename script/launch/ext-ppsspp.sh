#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh
. /opt/muos/script/var/device/sdl.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"

echo "PPSSPP" >/tmp/fg_proc

EMUDIR="$DC_STO_ROM_MOUNT/MUOS/emulator/ppsspp"

chmod +x "$EMUDIR"/ppsspp
cd "$EMUDIR" || exit

if [ "$DEVICE_TYPE" = "rg28xx" ]; then
	fbset -fb /dev/fb0 -g 720 960 720 1920 32
else
	fbset -fb /dev/fb0 -g 960 720 960 1440 32
fi

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./PPSSPP "$ROM"

if [ "$DEVICE_TYPE" = "rg28xx" ]; then
    fbset -fb /dev/fb0 -g 480 640 480 1280 32
else
    fbset -fb /dev/fb0 -g 640 480 640 960 32
fi