#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

(
	LOG_INFO "$0" 0 "Content Launch" "DETAIL"
	LOG_INFO "$0" 0 "NAME" "$NAME"
	LOG_INFO "$0" 0 "CORE" "$CORE"
	LOG_INFO "$0" 0 "FILE" "$FILE"
) &

GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"
MPV_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/mpv"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"

SET_VAR "system" "foreground_process" "mpv"

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

if [ "$CORE" = "ext-mpv-general" ]; then
	$GPTOKEYB "mpv" -c "$MPV_DIR/general.gptk" &
	/usr/bin/mpv "$FILE"
elif [ "$CORE" = "ext-mpv-livetv" ]; then
	$GPTOKEYB "mpv" -c "$MPV_DIR/livetv.gptk" &
	/usr/bin/mpv "$(cat "$FILE")"
# The following does not want to work for whatever reason!
#elif [ "$CORE" = "ext-mpv-radio" ]; then
#	cat /dev/zero >/dev/fb0 2>/dev/null
#	echo 4 >/sys/class/graphics/fb0/blank
#	$GPTOKEYB "mpv" -c "$MPV_DIR/radio.gptk" &
#	/usr/bin/mpv --no-video "$(cat "$FILE")"
#	echo 0 >/sys/class/graphics/fb0/blank
fi

killall -q gptokeyb2

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
