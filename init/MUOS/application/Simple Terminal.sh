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

export SDL_HQ_SCALER="$SDL_SCALER"

TERM_DIR="$STORE_ROM/MUOS/application/.terminal"

cd "$TERM_DIR" || exit

echo "terminal" > /tmp/fg_proc

ldconfig

LD_LIBRARY_PATH=/usr/lib32 HOME="$TERM_DIR" SDL_ASSERT=always_ignore ./terminal

