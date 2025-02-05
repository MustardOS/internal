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

SET_VAR "system" "foreground_process" "PPSSPP"

[ "$(GET_VAR "device" "screen/rotate")" -eq 1 ] && touch "/tmp/ignore_double"
FB_SWITCH 960 720 32

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp"

chmod +x "$EMUDIR"/ppsspp
cd "$EMUDIR" || exit

sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' "$EMUDIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

HOME="$EMUDIR" SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/opt/muos/device/current/control/gamecontrollerdb_retro.txt") ./PPSSPP --pause-menu-exit "$FILE"

[ "$(GET_VAR "global" "settings/hdmi/enabled")" -eq 1 ] && SCREEN_TYPE="external" || SCREEN_TYPE="internal"
FB_SWITCH "$(GET_VAR "device" "screen/$SCREEN_TYPE/width")" "$(GET_VAR "device" "screen/$SCREEN_TYPE/height")" 32

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
