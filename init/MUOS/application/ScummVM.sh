#!/bin/sh
# HELP: Script Creation Utility for Maniac Mansion Virtual Machine (ScummVM)
# ICON: scummvm

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

HOME="$(GET_VAR "device" "board/home")"
export HOME

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

SET_VAR "system" "foreground_process" "scummvm"

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/scummvm"
CONFIG="$EMUDIR/.config/scummvm/scummvm.ini"
LOGPATH="/mnt/mmc/MUOS/log/scummvm/log.txt"
SAVE="/run/muos/storage/save/file/ScummVM-Ext"

mkdir -p "$SAVE"
chmod +x "$EMUDIR"/scummvm

cd "$EMUDIR" || exit

# Switch analogue<>dpad for stickless devices
[ "$(GET_VAR "device" "board/stick")" -eq 0 ] && STICK_ROT=2 || STICK_ROT=0
case "$(GET_VAR "device" "board/name")" in
	rg*) echo "$STICK_ROT" >"/sys/class/power_supply/axp2202-battery/nds_pwrkey" ;;
	*) ;;
esac

HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG"

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
