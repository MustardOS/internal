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

# SDL Blitter is being commented out due to interference with mouse control
if [ "$(GET_VAR "global" "boot/device_mode")" -eq 1 ]; then
	SDL_HQ_SCALER=2
	SDL_ROTATION=0
	# SDL_BLITTER_DISABLED=1
else
	SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
	SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
	# SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
fi

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
LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/scummvm/log.txt"
SAVE="/run/muos/storage/save/file/ScummVM-Ext"

# Create log folder if it doesn't exist
mkdir -p "$(GET_VAR "device" "storage/rom/mount")/MUOS/log/scummvm"

mkdir -p "$SAVE"
chmod +x "$EMUDIR"/scummvm

cd "$EMUDIR" || exit

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

if [ "$SCVM" = "grim:grim" ]; then
	GRIMINI="$EMUDIR"/.config/scummvm/grimm.ini
	sed -i "s|^path=.*$|path=$F_PATH/$SUBFOLDER|" "$GRIMINI"
	if ! grep -q "\[grim-win\]" "$EMUDIR"/.config/scummvm/scummvm.ini; then
		cat "$EMUDIR"/.config/scummvm/grimm.ini >>"$EMUDIR"/.config/scummvm/scummvm.ini
	fi
	HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" "grim-win"
elif [ -z "$SCVM" ]; then
    # Switch analogue<>dpad for stickless devices
	[ "$(GET_VAR "device" "board/stick")" -eq 0 ] && STICK_ROT=2 || STICK_ROT=0
	case "$(GET_VAR "device" "board/name")" in
		rg*) echo "$STICK_ROT" >"/sys/class/power_supply/axp2202-battery/nds_pwrkey" ;;
		*) ;;
	esac

	HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" -p "$F_PATH/$SUBFOLDER" --auto-detect
else
	# Switch analogue<>dpad for stickless devices
	[ "$(GET_VAR "device" "board/stick")" -eq 0 ] && STICK_ROT=2 || STICK_ROT=0
	case "$(GET_VAR "device" "board/name")" in
		rg*) echo "$STICK_ROT" >"/sys/class/power_supply/axp2202-battery/nds_pwrkey" ;;
		*) ;;
	esac

	HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" -p "$F_PATH/$SUBFOLDER" "$SCVM"
fi

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
