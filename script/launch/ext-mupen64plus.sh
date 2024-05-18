#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

echo "mupen64plus" > /tmp/fg_proc

if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
	export SDL_HQ_SCALER=1
fi

EMUDIR="/mnt/mmc/MUOS/emulator/mupen64plus"
MP64_CFG="$EMUDIR/mupen64plus.cfg"

RICE_CFG="$EMUDIR/mupen64plus-rice.cfg"
GL64_CFG="$EMUDIR/mupen64plus-gl64.cfg"

if [ "$CORE" = "ext-mupen64plus-gliden64" ]; then
	cp -f "$GL64_CFG" "$MP64_CFG"
elif [ "$CORE" = "ext-mupen64plus-rice" ]; then
	echo "We need rice!" >> $LOG
	cp -f "$RICE_CFG" "$MP64_CFG"
fi

chmod +x $EMUDIR/mupen64plus
cd $EMUDIR || continue

fbset -fb /dev/fb0 -g 320 240 320 480 32

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./mupen64plus --corelib ./libmupen64plus.so.2.0.0 --configdir . "$ROM"

