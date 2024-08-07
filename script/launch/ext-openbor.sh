#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh
. /opt/muos/script/var/device/sdl.sh

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"

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

echo "$BOR_BIN" >/tmp/fg_proc

EMUDIR="/mnt/mmc/MUOS/emulator/openbor"

chmod +x $EMUDIR/"$BOR_BIN"
cd $EMUDIR || continue

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./"$BOR_BIN" "$ROM"

kill -9 "$(pidof $BOR_BIN)"

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED