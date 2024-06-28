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

TERM_DIR="$DC_STO_ROM_MOUNT/MUOS/application/.terminal"

cd "$TERM_DIR" || exit

echo "terminal" >/tmp/fg_proc

LD_LIBRARY_PATH=/usr/lib32 HOME="$TERM_DIR" SDL_ASSERT=always_ignore ./terminal
