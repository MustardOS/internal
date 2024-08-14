#!/bin/sh

. /opt/muos/script/var/func.sh

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mpg123"
fi

echo app >/tmp/act_go

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"

TERM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.terminal"

cd "$TERM_DIR" || exit

SET_VAR "system" "foreground_process" "terminal"

LD_LIBRARY_PATH=/usr/lib32 HOME="$TERM_DIR" SDL_ASSERT=always_ignore ./terminal -f ./res/SourceCodePro-Regular.ttf -s 14

unset SDL_HQ_SCALER
