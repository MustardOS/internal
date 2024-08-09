#!/bin/bash

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mpg123"
fi

echo app >/tmp/act_go

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

LOVEDIR="$DC_STO_ROM_MOUNT/MUOS/application/.moonlight"
MOONDIR="$DC_STO_ROM_MOUNT/MUOS/application/.moonlight/moonlight"
GPTOKEYB="$DC_STO_ROM_MOUNT/MUOS/emulator/gptokeyb/gptokeyb2.armhf"

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"

cd "$LOVEDIR" || exit
echo "love" >/tmp/fg_proc
export LD_LIBRARY_PATH="$LOVEDIR/libs:$LD_LIBRARY_PATH"
$GPTOKEYB "love" &
./love gui
kill -9 "$(pidof gptokeyb2.armhf)"

cd "$MOONDIR" || exit
COMMAND=$(cat command.txt)
eval "./moonlight $COMMAND"
rm -f "command.txt"
