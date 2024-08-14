#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

SET_VAR "system" "foreground_process" "pico8_64"

GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"
EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/pico8"

chmod +x "$EMUDIR"/wget
chmod +x "$EMUDIR"/pico8_64

cd "$EMUDIR" || exit

if [ "$NAME" = "Splore" ]; then
	SDL_ASSERT=always_ignore \
	SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") \
	$GPTOKEYB "./pico8_64" -c "./pico8.gptk" &
	PATH="$EMUDIR:$PATH" \
	HOME="$EMUDIR" \
	./pico8_64 -windowed 0 -splore
else
	SDL_ASSERT=always_ignore \
	SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") \
	$GPTOKEYB "./pico8_64" -c "./pico8.gptk" &
	PATH="$EMUDIR:$PATH" \
	HOME="$EMUDIR" \
	./pico8_64 -windowed 0 -run "$ROM"
fi

kill -9 "$(pidof pico8_64)" "$(pidof gptokeyb2)"

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
