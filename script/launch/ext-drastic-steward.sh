#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

EMUDIR="/$STORE_ROM/MUOS/emulator/drastic-steward"

chmod +x "$EMUDIR"/launch.sh
cd "$EMUDIR" || exit

HOME="$EMUDIR" SDL_ASSERT=always_ignore "$EMUDIR"/launch.sh "$ROM"

