#!/bin/sh

. /opt/muos/script/var/func.sh

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mpg123"
fi

echo app >/tmp/act_go

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"

DINGUX_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.dingux"

cd "$DINGUX_DIR" || exit

SET_VAR "system" "foreground_process" "dingux"

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") ./dingux --config "$DINGUX_DIR/dingux.cfg"

unset SDL_HQ_SCALER
