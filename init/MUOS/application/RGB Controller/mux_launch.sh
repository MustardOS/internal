#!/bin/bash
# HELP: RGB Controller
# ICON: rgbcontroller
# GRID: RGB

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

GOV_GO="/tmp/gov_go"
[ -e "$GOV_GO" ] && cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"

CON_GO="/tmp/con_go"
SETUP_SDL_ENVIRONMENT

LOVEDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/RGB Controller"
GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"
CONFDIR="$LOVEDIR/conf/"

export XDG_DATA_HOME="$CONFDIR"

cd "$LOVEDIR" || exit
SET_VAR "system" "foreground_process" "love"
export LD_LIBRARY_PATH="$LOVEDIR/libs:$LD_LIBRARY_PATH"
$GPTOKEYB "love" &
./love rgbcontroller
kill -9 "$(pidof gptokeyb2)"

[ -e "$GOV_GO" ] && rm -f "$GOV_GO"
[ -e "$CON_GO" ] && rm -f "$CON_GO"

SET_DEFAULT_GOVERNOR
unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
