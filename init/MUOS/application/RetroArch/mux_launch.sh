#!/bin/sh
# HELP: RetroArch
# ICON: retroarch
# GRID: RetroArch

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

GOV_GO="/tmp/gov_go"
[ -e "$GOV_GO" ] && cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"

SETUP_SDL_ENVIRONMENT

HOME="$(GET_VAR "device" "board/home")"
export HOME

SET_VAR "system" "foreground_process" "retroarch"

RA_CONF="/run/muos/storage/info/config/retroarch.cfg"
RA_ARGS=$(CONFIGURE_RETROARCH "$RA_CONF")

IS_SWAP=$(DETECT_CONTROL_SWAP)

/usr/bin/retroarch -v -f -c "$RA_CONF" $RA_ARGS

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
