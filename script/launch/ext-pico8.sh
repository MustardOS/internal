#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh
. /opt/muos/script/var/device/sdl.sh

NAME=$1
CORE=$2
ROM=$3

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"

echo "pico8_64" >/tmp/fg_proc

GPTOKEYB="$DC_STO_ROM_MOUNT/MUOS/emulator/gptokeyb/gptokeyb2"

EMUDIR="$DC_STO_ROM_MOUNT/MUOS/emulator/pico8"

chmod +x "$EMUDIR"/wget
chmod +x "$EMUDIR"/pico8_64

cd "$EMUDIR" || exit

if [ "$NAME" = "Splore" ]; then
	SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") $GPTOKEYB "./pico8_64" -c "./pico8.gptk" &
PATH="$EMUDIR:$PATH" HOME="$EMUDIR" ./pico8_64 -windowed 0 -splore
else
	SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") $GPTOKEYB "./pico8_64" -c "./pico8.gptk" &
PATH="$EMUDIR:$PATH" HOME="$EMUDIR" ./pico8_64 -windowed 0 -run "$ROM"
fi
kill -9 "$(pidof pico8_64)"
kill -9 "$(pidof gptokeyb2)"
