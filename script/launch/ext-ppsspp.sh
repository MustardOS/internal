#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

LOG_INFO "$0" 0 "CONTENT LAUNCH" "NAME: %s\tCORE: %s\tROM: %s\n" "$NAME" "$CORE" "$ROM"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

SET_VAR "system" "foreground_process" "PPSSPP"

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp"

chmod +x "$EMUDIR"/ppsspp
cd "$EMUDIR" || exit

case "$(GET_VAR "device" "board/name")" in
	rg28xx-h)
		FB_SWITCH 720 960 32
		;;
	*)
		FB_SWITCH 960 720 32
		;;
esac

sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' "$EMUDIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/opt/muos/device/current/control/gamecontrollerdb_retro.txt") ./PPSSPP "$ROM"

case "$(GET_VAR "device" "board/name")" in
	rg*)
		echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"
		FB_SWITCH "$(GET_VAR "device" "screen/width")" "$(GET_VAR "device" "screen/height")" 32
		;;
	*)
		FB_SWITCH "$(GET_VAR "device" "screen/width")" "$(GET_VAR "device" "screen/height")" 32
		;;
esac

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
