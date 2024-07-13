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

. /opt/muos/script/var/device/device.sh
. /opt/muos/script/var/device/sdl.sh
. /opt/muos/script/var/device/storage.sh

GPTOKEYB="$DC_STO_ROM_MOUNT/MUOS/emulator/gptokeyb/gptokeyb2"

export LD_LIBRARY_PATH=/usr/lib32

export SDL_HQ_SCALER="$DC_SDL_SCALER"
if [ $DC_DEV_NAME = "RG28XX" ]; then
    export SDL_ROTATION=0
else
    export SDL_ROTATION=3
fi

FLIPCLOCK_DIR="$DC_STO_ROM_MOUNT/MUOS/application/.flipclock"

cd "$FLIPCLOCK_DIR" || exit

echo "flipclock" >/tmp/fg_proc

HOME="$FLIPCLOCK_DIR" SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib32/gamecontrollerdb.txt") $GPTOKEYB "./flipclock" -c "./flipclock.gptk" &
./flipclock

# Cleanup on exit
kill -9 "$(pidof flipclock)"
kill -9 "$(pidof gptokeyb2)"
unset SDL_HQ_SCALER
unset SDL_ROTATION
unset LD_LIBRARY_PATH