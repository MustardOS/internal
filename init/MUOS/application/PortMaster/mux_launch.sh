#!/bin/sh
# HELP: PortMaster
# ICON: portmaster
# GRID: PortMaster

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

GOV_GO="/tmp/gov_go"
[ -e "$GOV_GO" ] && cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"

SETUP_SDL_ENVIRONMENT

HOME="$(GET_VAR "device" "board/home")"
export HOME

SET_VAR "system" "foreground_process" "portmaster"

PORTMASTER_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
cd "$PORTMASTER_DIR" || exit

./PortMaster.sh

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
