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

[ "$(GET_VAR "device" "screen/rotate")" -eq 1 ] && touch "/tmp/ignore_double"
FB_SWITCH 960 720 32

sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/opt/muos/device/current/control/gamecontrollerdb_retro.txt") ./PPSSPP

[ "$(GET_VAR "global" "settings/hdmi/enabled")" -eq 1 ] && SCREEN_TYPE="external" || SCREEN_TYPE="internal"
FB_SWITCH "$(GET_VAR "device" "screen/$SCREEN_TYPE/width")" "$(GET_VAR "device" "screen/$SCREEN_TYPE/height")" 32

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
