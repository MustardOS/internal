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

SET_VAR "system" "foreground_process" "drastic"

EMUDIR="/opt/muos/share/emulator/drastic-trngaje"

chmod +x "$EMUDIR"/launch.sh
cd "$EMUDIR" || exit

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

HOME="$EMUDIR" ./launch.sh "$FILE"

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
