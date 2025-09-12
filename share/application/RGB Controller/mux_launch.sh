#!/bin/bash
# HELP: RGB Controller
# ICON: rgbcontroller
# GRID: RGB

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

GOV_GO="/tmp/gov_go"
[ -e "$GOV_GO" ] && cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"

SETUP_SDL_ENVIRONMENT

LOVEDIR="$1"

GPTOKEYB="/opt/muos/share/emulator/gptokeyb/gptokeyb2"
CONFDIR="$LOVEDIR/conf/"

export XDG_DATA_HOME="$CONFDIR"

cd "$LOVEDIR" || exit
SET_VAR "system" "foreground_process" "love"
export LD_LIBRARY_PATH="$LOVEDIR/libs:$LD_LIBRARY_PATH"
$GPTOKEYB "love" &
./love rgbcontroller
kill -9 "$(pidof gptokeyb2)"

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
