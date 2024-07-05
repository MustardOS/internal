#!/bin/sh

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mp3play"
fi

if pgrep -f "muplay" >/dev/null; then
	killall -q "muplay"
	rm "$SND_PIPE"
fi

echo app >/tmp/act_go

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

GMU_DIR="$DC_STO_ROM_MOUNT/MUOS/application/.gmu"
GPTOKEYB="$DC_STO_ROM_MOUNT/MUOS/emulator/gptokeyb/gptokeyb2.armhf"

cd "$GMU_DIR" || exit

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib32/gamecontrollerdb.txt"
export LD_LIBRARY_PATH=/usr/lib32

echo "gmu" >/tmp/fg_proc

$GPTOKEYB "gmu" -c "$GMU_DIR/gmu.gptk" &
SDL_ASSERT=always_ignore $SDL_GAMECONTROLLERCONFIG ./gmu -d "$GMU_DIR" -c "$GMU_DIR/gmu.conf"

# Cleanup on exit
kill -9 "$(pidof gptokeyb2.armhf)"
unset SDL_GAMECONTROLLERCONFIG_FILE
unset LD_LIBRARY_PATH