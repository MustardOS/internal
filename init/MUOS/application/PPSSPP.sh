#!/bin/sh
# HELP: PPSSPP
# ICON: ppsspp

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

PPSSPP_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp"
HOME="$PPSSPP_DIR"
export HOME

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

cd "$PPSSPP_DIR" || exit

SET_VAR "system" "foreground_process" "PPSSPP"

if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 0 ]; then
	case "$(GET_VAR "device" "screen/rotate")" in
		1) FB_SWITCH 720 960 32 ;;
		0 | 2) FB_SWITCH 960 720 32 ;;
	esac
fi

sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/opt/muos/device/current/control/gamecontrollerdb_retro.txt") ./PPSSPP

if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 1 ]; then
	HDMI_SWITCH
else
	FB_SWITCH "$(GET_VAR "device" "screen/internal/width")" "$(GET_VAR "device" "screen/internal/height")" 32
fi

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
