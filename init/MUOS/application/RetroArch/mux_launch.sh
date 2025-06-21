#!/bin/sh
# HELP: RetroArch
# ICON: retroarch
# GRID: RetroArch

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_CONF="/run/muos/storage/info/config/retroarch.cfg"
CONFIGURE_RETROARCH "$RA_CONF"

nice --20 /usr/bin/retroarch -v -f -c "$RA_CONF"
RA_PID=$!

wait $RA_PID
unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
