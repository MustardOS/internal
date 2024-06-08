#!/bin/sh

if pgrep -f "playbgm.sh" > /dev/null; then
	killall -q "playbgm.sh"
	killall -q "mp3play"
fi

if pgrep -f "muplay" > /dev/null; then
	kill -9 "muplay"
	rm "$SND_PIPE"
fi

echo app > /tmp/act_go

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")

GMU_DIR="$STORE_ROM/MUOS/application/.gmu"
GPTOKEYB="$STORE_ROM/MUOS/emulator/gptokeyb/gptokeyb2.armhf"

cd "$GMU_DIR" || exit

export SDL_GAMECONTROLLER="/usr/lib32/gamecontrollerdb.txt"
export HOME=/root
export LD_LIBRARY_PATH=/usr/lib32

echo "gmu" > /tmp/fg_proc

$GPTOKEYB "gmu" -c "$GMU_DIR/gmu.gptk" &
SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "$SDL_GAMECONTROLLER") ./gmu -d "$GMU_DIR" -c "$GMU_DIR/gmu.conf"

kill -9 $(pidof gptokeyb2)
