#!/bin/sh
# HELP: scummvm
# ICON: scummvm

. /opt/muos/script/var/func.sh

export HOME=$(GET_VAR "device" "board/home")

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

SET_VAR "system" "foreground_process" "scummvm"

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/scummvm"
CONFIG="$EMUDIR/.config/scummvm/scummvm.ini"
LOGPATH="/mnt/mmc/MUOS/log/scummvm/log.txt"
SAVE="/run/muos/storage/save/file/ScummVM-Ext"

mkdir -p "$SAVE"
chmod +x "$EMUDIR"/scummvm

cd "$EMUDIR" || exit

# Switch analogue<>dpad for stickless devices
case "$(GET_VAR "device" "board/name")" in
  	rg28xx|rg35xx-2024|rg35xx-plus|rg35xx-sp)
       	echo 2 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"
       	;;
   	*)
      	echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"
       	;;
esac
HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/usr/lib/gamecontrollerdb.txt") nice --20 ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG"
fi

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
