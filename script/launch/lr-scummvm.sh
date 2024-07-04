#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh
. /opt/muos/script/var/device/sdl.sh

. /opt/muos/script/var/global/setting_general.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"

echo "retroarch" >/tmp/fg_proc

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')

if [ -d "$ROMPATH/.$NAME" ]; then
	SUBFOLDER=".$NAME"
else
	SUBFOLDER="$NAME"
fi

SCVM="$ROMPATH/$SUBFOLDER/$NAME.scummvm"

cp "$ROMPATH/$NAME.scummvm" "$SCVM"

retroarch -v -f -c "$DC_STO_ROM_MOUNT/MUOS/retroarch/retroarch.cfg" -L "$DC_STO_ROM_MOUNT/MUOS/core/scummvm_libretro.so" "$SCVM" &
RA_PID=$!

# We have to pause just for a moment to let RetroArch finish loading...
sleep 5

if [ "$GC_GEN_STARTUP" = last ] || [ "$GC_GEN_STARTUP" = resume ]; then
	if [ ! -e "/tmp/manual_launch" ]; then
		retroarch --command LOAD_STATE
	fi
fi

wait $RA_PID
