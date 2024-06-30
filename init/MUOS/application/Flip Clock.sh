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

. /opt/muos/script/var/device/sdl.sh
. /opt/muos/script/var/device/storage.sh

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION=3

export SDL_GAMECONTROLLER="/usr/lib/gamecontrollerdb.txt"
export HOME=/root

FLIPCLOCK_DIR="$DC_STO_ROM_MOUNT/MUOS/application/.flipclock"

cd "$FLIPCLOCK_DIR" || exit

echo "flipclock" >/tmp/fg_proc

LD_LIBRARY_PATH=/usr/lib32 HOME="$FLIPCLOCK_DIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "$SDL_GAMECONTROLLER") ./flipclock
