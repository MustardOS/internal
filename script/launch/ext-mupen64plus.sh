#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")
SDL_ROTATE=$(parse_ini "$DEVICE_CONFIG" "sdl" "rotate")

NAME=$1
CORE=$2
ROM=$3

export HOME=/root
export SDL_HQ_SCALER="$SDL_SCALER"
export SDL_ROTATION="$SDL_ROTATE"

echo "mupen64plus" > /tmp/fg_proc

if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
	export SDL_HQ_SCALER=1
	export SDL_ROTATION=1
fi

EMUDIR="$STORE_ROM/MUOS/emulator/mupen64plus"
MP64_CFG="$EMUDIR/mupen64plus.cfg"

RICE_CFG="$EMUDIR/mupen64plus-rice.cfg"
GL64_CFG="$EMUDIR/mupen64plus-gl64.cfg"

if [ "$CORE" = "ext-mupen64plus-gliden64" ]; then
	cp -f "$GL64_CFG" "$MP64_CFG"
elif [ "$CORE" = "ext-mupen64plus-rice" ]; then
	echo "We need rice!" >> "$LOG"
	cp -f "$RICE_CFG" "$MP64_CFG"
fi

chmod +x "$EMUDIR"/mupen64plus
cd "$EMUDIR" || exit

fbset -fb /dev/fb0 -g 320 240 320 480 32

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./mupen64plus --corelib ./libmupen64plus.so.2.0.0 --configdir . "$ROM"

