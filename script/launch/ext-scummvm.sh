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

if [ "$SCVM" = "grim:grim" ]; then
	GRIMINI="$EMUDIR"/.config/scummvm/grimm.ini
	sed -i "s|^path=.*$|path=$ROMPATH/$SUBFOLDER|" "$GRIMINI"
	if ! grep -q "\[grim-win\]" "$EMUDIR"/.config/scummvm/scummvm.ini; then
		cat "$EMUDIR"/.config/scummvm/grimm.ini >>"$EMUDIR"/.config/scummvm/scummvm.ini
	fi
	HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --joystick=0 --themepath="$THEME" --aspect-ratio -f "grim-win"
else
	# Switch analogue<>dpad for stickless devices
	case "$(GET_VAR "device" "board/name")" in
    	rg28xx|rg35xx-2024|rg35xx-plus|rg35xx-sp)
        	echo 2 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"
        	;;
    	*)
       		echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"
        	;;
	esac
	HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --joystick=0 --aspect-ratio -f --extrapath="$EXTRA" --themepath="$THEME" --savepath="$SAVE" -p "$ROMPATH/$SUBFOLDER" "$SCVM"
fi

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
