#!/bin/sh
# HELP: Simple Terminal
# ICON: terminal

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_HQ_SCALER

TERM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.terminal"

cd "$TERM_DIR" || exit

SET_VAR "system" "foreground_process" "terminal"

LD_LIBRARY_PATH=/usr/lib32 HOME="$TERM_DIR" SDL_ASSERT=always_ignore ./terminal -f ./res/SourceCodePro-Regular.ttf -s 14

unset SDL_HQ_SCALER
