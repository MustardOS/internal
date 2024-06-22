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

export SDL_HQ_SCALER="$SDL_SCALER"
export SDL_GAMECONTROLLER="/usr/lib/gamecontrollerdb.txt"
export HOME=/root

MOONLIGHT_DIR="$STORE_ROM/MUOS/application/.moonlight"
MOONLIGHT_CFG="$MOONLIGHT_DIR/moonlight.conf"

cd "$MOONLIGHT_DIR" || exit

echo "muxmoon" > /tmp/fg_proc

nice --20 /opt/muos/extra/muxmoon

