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

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"
export SDL_GAMECONTROLLER="$PPSSPP_DIR/gamecontrollerdb.txt"
export HOME=/root

PPSSPP_DIR="$DC_STO_ROM_MOUNT/MUOS/emulator/ppsspp"

cd "$PPSSPP_DIR" || exit

echo "PPSSPP" >/tmp/fg_proc

fbset -fb /dev/fb0 -g 960 720 960 1440 32

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "$SDL_GAMECONTROLLER") ./PPSSPP

fbset -fb /dev/fb0 -g 640 480 640 960 32

