#!/bin/sh
# HELP: PortMaster
# ICON: portmaster
# GRID: PortMaster

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "portmaster"

nice --20 "$(GET_VAR "device" "storage/rom/mount")"/MUOS/PortMaster/PortMaster.sh

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
