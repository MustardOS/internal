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

DINGUX_DIR="$DC_STO_ROM_MOUNT/MUOS/application/.dingux"

cd "$DINGUX_DIR" || exit

echo "dingux" >/tmp/fg_proc

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") ./dingux --config "$DINGUX_DIR/dingux.cfg"

# Cleanup on exit
unset SDL_HQ_SCALER