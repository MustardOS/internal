#!/bin/sh

# muOS v11 compatibility
if [ -d "/usr/lib32" ]; then
    export LD_LIBRARY_PATH=/usr/lib32
fi

# Check for RG28XX and rotate screen if found
if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
	export SDL_HQ_SCALER=1
fi

PORTS_FOLDER=$(realpath "$(dirname "$0")")
cd "$PORTS_FOLDER"
cd "terminal"
GAMEDIR="$PORTS_FOLDER"
HOME="$GAMEDIR" SDL_ASSERT=always_ignore ./terminal

