#!/bin/sh
# HELP: Flip Clock
# ICON: flip

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"

export LD_LIBRARY_PATH=/usr/lib32

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"

if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 0 ]; then
	case "$(GET_VAR "device" "screen/rotate")" in
		1) export SDL_ROTATION=0 ;;
		0 | 2) export SDL_ROTATION=3 ;;
	esac
fi

FLIPCLOCK_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.flipclock"

cd "$FLIPCLOCK_DIR" || exit

SET_VAR "system" "foreground_process" "flipclock"

HOME="$FLIPCLOCK_DIR" SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib32/gamecontrollerdb.txt") $GPTOKEYB "./flipclock" -c "./flipclock.gptk" &
./flipclock

kill -9 "$(pidof flipclock)"
kill -9 "$(pidof gptokeyb2)"

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset LD_LIBRARY_PATH
