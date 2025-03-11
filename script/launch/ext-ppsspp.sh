#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

PPSSPP_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp"
HOME="$PPSSPP_DIR"
export HOME

if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 1 ] && [ "$(GET_VAR "device" "board/hdmi")" -eq 1 ]; then
	SDL_HQ_SCALER=2
	SDL_ROTATION=0
	SDL_BLITTER_DISABLED=1
else
	SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
	SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
	SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
fi

export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

cd "$PPSSPP_DIR" || exit

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

SET_VAR "system" "foreground_process" "PPSSPP"

FB_SWITCH 960 720 32

sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/opt/muos/device/current/control/gamecontrollerdb_retro.txt") ./PPSSPP --pause-menu-exit "$FILE"

# Do it twice, it's just as nice!
cat /dev/zero >"$(GET_VAR "device" "screen/device")" 2>/dev/null
cat /dev/zero >"$(GET_VAR "device" "screen/device")" 2>/dev/null

SCREEN_TYPE="internal"
if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 1 ] && [ "$(GET_VAR "device" "board/hdmi")" -eq 1 ]; then
	SCREEN_TYPE="external"
fi

FB_SWITCH "$(GET_VAR "device" "screen/$SCREEN_TYPE/width")" "$(GET_VAR "device" "screen/$SCREEN_TYPE/height")" 32

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
