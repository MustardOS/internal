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

if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 0 ]; then
	case "$(GET_VAR "device" "screen/rotate")" in
		1) FB_SWITCH 720 960 32 ;;
		0 | 2) FB_SWITCH 960 720 32 ;;
	esac
fi

sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' "$EMUDIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/opt/muos/device/current/control/gamecontrollerdb_retro.txt") ./PPSSPP "$ROM"

if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 1 ]; then
	HDMI_SWITCH
else
	FB_SWITCH "$(GET_VAR "device" "screen/internal/width")" "$(GET_VAR "device" "screen/internal/height")" 32
fi

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
