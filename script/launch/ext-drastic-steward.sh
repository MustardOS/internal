#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

#if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
#	export SDL_HQ_SCALER=1
#fi

EMUDIR="/mnt/mmc/MUOS/emulator/drastic-steward"

chmod +x $EMUDIR/launch.sh
cd $EMUDIR || continue

HOME="$EMUDIR" SDL_ASSERT=always_ignore "$EMUDIR"/launch.sh "$ROM"

