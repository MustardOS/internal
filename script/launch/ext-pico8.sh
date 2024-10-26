#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3
ROMDIR="$(dirname "$ROM")"

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

SET_VAR "system" "foreground_process" "pico8_64"

GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"
EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/pico8"
CTRL_TYPE="$(GET_VAR "global" "settings/advanced/swap")"

# Set appropriate sdl controller file
if [ "$CTRL_TYPE" = 0 ]; then
	export SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/opt/muos/device/current/control/gamecontrollerdb_modern.txt")
else
	export SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/opt/muos/device/current/control/gamecontrollerdb_retro.txt")
fi

# First look for emulator in BIOS directory, which allows it to follow the
# user's storage preference. Fall back on the old path for compatibility.
EMU="/run/muos/storage/bios/pico8/pico8_64"
if [ ! -f "$EMU" ]; then
	EMU="$EMUDIR/pico8_64"
fi

# Did the user select standard or Pixel Perfect scaler?
if [ "$CORE" = "ext-pico8-scale" ]; then
	PICO_FLAGS="-windowed 0"
elif [ "$CORE" = "ext-pico8-pixel" ]; then
	PICO_FLAGS="-windowed 0 -pixel_perfect 1"
fi

chmod +x "$EMUDIR"/wget
chmod +x "$EMU"

cd "$EMUDIR" || exit

if [ "$NAME" = "Splore" ]; then
	SDL_ASSERT=always_ignore \
	$GPTOKEYB "./pico8_64" -c "./pico8.gptk" &
	PATH="$EMUDIR:$PATH" \
	HOME="$EMUDIR" \
	"$EMU" $PICO_FLAGS -root_path "$ROMDIR" -splore
else
	SDL_ASSERT=always_ignore \
	$GPTOKEYB "./pico8_64" -c "./pico8.gptk" &
	PATH="$EMUDIR:$PATH" \
	HOME="$EMUDIR" \
	"$EMU" $PICO_FLAGS -root_path "$ROMDIR" -run "$ROM"
fi

kill -9 "$(pidof pico8_64)" "$(pidof gptokeyb2)"

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
