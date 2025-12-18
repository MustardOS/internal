#!/bin/sh
# HELP: Dingux Commander
# ICON: dingux
# GRID: Dingux

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

GOV_GO="/tmp/gov_go"
[ -e "$GOV_GO" ] && cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "dingux"

DINGUX_DIR="$1"
cd "$DINGUX_DIR" || exit

if [ "$(GET_VAR "device" "mux/width")" -gt 1000 ]; then
    ./dingux --config "$DINGUX_DIR/dingux-hi-res.cfg" --res-dir "res-hi"
else
    ./dingux --config "$DINGUX_DIR/dingux.cfg"
fi

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
