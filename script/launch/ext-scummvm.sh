#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

SET_VAR "system" "foreground_process" "scummvm"

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')
SCVM=$(tr -d '[:space:]' <"$F_PATH/$NAME.scummvm" | head -n 1)

if [ -d "$F_PATH/.$NAME" ]; then
	SUBFOLDER=".$NAME"
else
	SUBFOLDER="$NAME"
fi

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/scummvm"
CONFIG="$EMUDIR/.config/scummvm/scummvm.ini"
LOGPATH="/mnt/mmc/MUOS/log/scummvm/log.txt"
SAVE="/run/muos/storage/save/file/ScummVM-Ext"

# Create log folder if it doesn't exist
mkdir -p "/mnt/mmc/MUOS/log/scummvm"

mkdir -p "$SAVE"
chmod +x "$EMUDIR"/scummvm

cd "$EMUDIR" || exit

if [ "$SCVM" = "grim:grim" ]; then
	GRIMINI="$EMUDIR"/.config/scummvm/grimm.ini
	sed -i "s|^path=.*$|path=$F_PATH/$SUBFOLDER|" "$GRIMINI"
	if ! grep -q "\[grim-win\]" "$EMUDIR"/.config/scummvm/scummvm.ini; then
		cat "$EMUDIR"/.config/scummvm/grimm.ini >>"$EMUDIR"/.config/scummvm/scummvm.ini
	fi
	HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" "grim-win"
else
	# Switch analogue<>dpad for stickless devices
	[ "$(GET_VAR "device" "board/stick")" -eq 0 ] && STICK_ROT=2 || STICK_ROT=0
	case "$(GET_VAR "device" "board/name")" in
		rg*) echo "$STICK_ROT" >"/sys/class/power_supply/axp2202-battery/nds_pwrkey" ;;
		*) ;;
	esac

	HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" -p "$F_PATH/$SUBFOLDER" "$SCVM"
fi

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
