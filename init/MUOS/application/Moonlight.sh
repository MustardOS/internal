#!/bin/sh
# HELP: Moonlight
# ICON: moonlight

. /opt/muos/script/var/func.sh

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mpg123"
fi

echo app >/tmp/act_go

LOVEDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.moonlight"
MOONDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.moonlight/moonlight"
GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2.armhf"

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"

cd "$LOVEDIR" || exit
SET_VAR "system" "foreground_process" "love"
export LD_LIBRARY_PATH="$LOVEDIR/libs:$LD_LIBRARY_PATH"
$GPTOKEYB "love" &
./love gui
kill -9 "$(pidof gptokeyb2.armhf)"

cd "$MOONDIR" || exit
COMMAND=$(cat command.txt)
eval "./moonlight $COMMAND"
rm -f "command.txt"
