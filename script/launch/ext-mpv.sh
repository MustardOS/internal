#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"
MPV_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/mpv"

export HOME=$(GET_VAR "device" "board/home")

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"

SET_VAR "system" "foreground_process" "mpv"

if [ "$CORE" = "ext-mpv-general" ]; then
	$GPTOKEYB "mpv" -c "$MPV_DIR/general.gptk" &
	/usr/bin/mpv "$ROM"
elif [ "$CORE" = "ext-mpv-livetv" ]; then
	$GPTOKEYB "mpv" -c "$MPV_DIR/livetv.gptk" &
	/usr/bin/mpv "$(cat "$ROM")"
# The following does not want to work for whatever reason!
#elif [ "$CORE" = "ext-mpv-radio" ]; then
#	cat /dev/zero >/dev/fb0 2>/dev/null
#	echo 4 >/sys/class/graphics/fb0/blank
#	$GPTOKEYB "mpv" -c "$MPV_DIR/radio.gptk" &
#	/usr/bin/mpv --no-video "$(cat "$ROM")"
#	echo 0 >/sys/class/graphics/fb0/blank
fi

killall -q gptokeyb2

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
