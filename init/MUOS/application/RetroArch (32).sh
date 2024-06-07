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

export HOME=/root

echo "retroarch32" > /tmp/fg_proc

ldconfig

LD_LIBRARY_PATH=/usr/lib32 nice --20 /usr/bin/retroarch32 -v -f -c "$STORE_ROM/MUOS/retroarch/retroarch32.cfg"

