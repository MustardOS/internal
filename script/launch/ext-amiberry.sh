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

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "amiberry"

EMUDIR="$MUOS_SHARE_DIR/emulator/amiberry"

chmod +x "$EMUDIR"/amiberry
cd "$EMUDIR" || exit

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

HOME="$EMUDIR" ./amiberry "$FILE"

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
