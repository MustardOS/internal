#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

. /opt/muos/script/var/func.sh

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

# Create needed symlink as required.
if [ ! -L "/userdata" ]; then
    ln -s /mnt/mmc/muos/emulator/openbor/userdata /userdata
fi

if [ "$CORE" = "ext-openbor4432" ]; then
	BOR_BIN="OpenBOR4432"
elif [ "$CORE" = "ext-openbor6412" ]; then
	BOR_BIN="OpenBOR6412"
elif [ "$CORE" = "ext-openbor7142" ]; then
	BOR_BIN="OpenBOR7142"
elif [ "$CORE" = "ext-openbor7530" ]; then
	BOR_BIN="OpenBOR7530"
fi

SET_VAR "system" "foreground_process" "$BOR_BIN"

EMUDIR="/mnt/mmc/MUOS/emulator/openbor"

chmod +x $EMUDIR/"$BOR_BIN"
cd $EMUDIR || continue

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./"$BOR_BIN" "$ROM"

kill -9 "$(pidof $BOR_BIN)"

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED