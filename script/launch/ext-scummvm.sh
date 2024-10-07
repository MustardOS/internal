#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=$(GET_VAR "device" "board/home")

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

SET_VAR "system" "foreground_process" "scummvm"

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')
SCVM=$(cat "$ROMPATH/$NAME.scummvm")

if [ -d "$ROMPATH/.$NAME" ]; then
	SUBFOLDER=".$NAME"
else
	SUBFOLDER="$NAME"
fi

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/scummvm"
EXTRA="$EMUDIR/Extra"
THEME="$EMUDIR/Theme"
SAVE="/run/muos/storage/save/file/ScummVM-Ext"

mkdir -p "$SAVE"
chmod +x "$EMUDIR"/scummvm

cd "$EMUDIR" || exit

echo "SCVM var is $SCVM" > "$EMUDIR/log.txt"

if [ "$SCVM" = "grim:grim" ]; then
	GRIMINI="$EMUDIR"/.config/scummvm/grimm.ini
	sed -i "s|^path=.*$|path=$ROMPATH/$SUBFOLDER|" "$GRIMINI"
	if ! grep -q "\[grim-win\]" "$EMUDIR"/.config/scummvm/scummvm.ini; then
		cat "$EMUDIR"/.config/scummvm/grimm.ini >>"$EMUDIR"/.config/scummvm/scummvm.ini
	fi
    echo "Game found: $SCVM - Grim Detected!" >> "$EMUDIR/log.txt"
	HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --joystick=0 --themepath="$THEME" --aspect-ratio -f "grim-win"
else
	echo "Game found: $SCVM - Grim NOT Detected!" >> "$EMUDIR/log.txt"
	HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --joystick=0 --aspect-ratio -f --extrapath="$EXTRA" --themepath="$THEME" --savepath="$SAVE" -p "$ROMPATH/$SUBFOLDER" "$SCVM"
fi

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
