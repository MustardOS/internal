#!/bin/sh

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mp3play"
fi

if pgrep -f "muplay" >/dev/null; then
	killall -q "muplay"
	rm "$SND_PIPE"
fi

echo app >/tmp/act_go

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh
. /opt/muos/script/var/device/sdl.sh

PPSSPP_DIR="$DC_STO_ROM_MOUNT/MUOS/emulator/ppsspp"

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"
export HOME=$PPSSPP_DIR

cd "$PPSSPP_DIR" || exit

echo "PPSSPP" >/tmp/fg_proc

if [ "$DEVICE_TYPE" = "rg28xx" ]; then
	fbset -fb /dev/fb0 -g 720 960 720 1920 32
else
	fbset -fb /dev/fb0 -g 960 720 960 1440 32
fi

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") ./PPSSPP

if [ "$DEVICE_TYPE" = "rg28xx" ]; then
    fbset -fb /dev/fb0 -g 480 640 480 1280 32
else
    fbset -fb /dev/fb0 -g 640 480 640 960 32
fi

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED