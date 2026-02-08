#!/bin/sh
# HELP: Moonlight
# ICON: moonlight
# GRID: Moonlight

. /opt/muos/script/var/func.sh

APP_BIN="love"
SETUP_APP "$APP_BIN" ""

# -----------------------------------------------------------------------------

LOVEDIR="$1"
MOONDIR="$1/moonlight"

cd "$LOVEDIR" || exit

SET_VAR "system" "foreground_process" "love"
export LD_LIBRARY_PATH="$LOVEDIR/libs:$LD_LIBRARY_PATH"

PM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
"$PM_DIR"/gptokeyb2 "$APP_BIN" &

./$APP_BIN gui
kill -9 "$(pidof gptokeyb2)"

cd "$MOONDIR" || exit
COMMAND=$(cat command.txt)

eval "./moonlight $COMMAND"
rm -f "command.txt"
