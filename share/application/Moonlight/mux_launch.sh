#!/bin/sh
# HELP: Moonlight
# ICON: moonlight
# GRID: Moonlight

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

GOV_GO="/tmp/gov_go"
[ -e "$GOV_GO" ] && cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"

SETUP_SDL_ENVIRONMENT

LOVEDIR="$1"
MOONDIR="$1/moonlight"

PM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
GPTOKEYB="$PM_DIR"/gptokeyb2

cd "$LOVEDIR" || exit
SET_VAR "system" "foreground_process" "love"
export LD_LIBRARY_PATH="$LOVEDIR/libs:$LD_LIBRARY_PATH"
$GPTOKEYB "love" &
./love gui
kill -9 "$(pidof gptokeyb2)"

cd "$MOONDIR" || exit
COMMAND=$(cat command.txt)
eval "./moonlight $COMMAND"
rm -f "command.txt"

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
