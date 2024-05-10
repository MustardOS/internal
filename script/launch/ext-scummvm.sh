#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
	export SDL_HQ_SCALER=1
fi

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')
SCVM=$(cat "$ROMPATH/$NAME.scummvm")

if [ -d "$ROMPATH/.$NAME" ]; then
	SUBFOLDER=".$NAME"
else
	SUBFOLDER="$NAME"
fi

EMUDIR="/mnt/mmc/MUOS/emulator/scummvm"
EXTRA="$EMUDIR/Extra"
THEME="$EMUDIR/Theme"
SAVE="/mnt/mmc/MUOS/save/file/ScummVM-Ext"

mkdir -p "$SAVE"
chmod +x $EMUDIR/scummvm

cd $EMUDIR || exit
if [ "$SCVM" = "grim:grim" ]; then
	GRIMINI=$EMUDIR/.config/scummvm/grimm.ini
	sed -i "s|^path=.*$|path=$ROMPATH/$SUBFOLDER|" $GRIMINI
	if ! grep -q "\[grim-win\]" $EMUDIR/.config/scummvm/scummvm.ini; then
		cat $EMUDIR/.config/scummvm/grimm.ini >> $EMUDIR/.config/scummvm/scummvm.ini
	fi
	HOME="$EMUDIR" SDL_ASSERT=always_ignore nice --20 ./scummvm --themepath=$THEME --aspect-ratio -f "grim-win"
else	
	HOME="$EMUDIR" SDL_ASSERT=always_ignore nice --20 ./scummvm --aspect-ratio -f --extrapath=$EXTRA --themepath=$THEME --savepath=$SAVE -p "$ROMPATH/$SUBFOLDER" "$SCVM"
fi

