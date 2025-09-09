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

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)
IS_SWAP=$(DETECT_CONTROL_SWAP)

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

nice --20 retroarch -v -f $RA_ARGS -L "$MUOS_SHARE_DIR/core/2048_libretro.so" "$FILE"

for RF in ra_no_load ra_autoload_once.cfg; do
	[ -e "/tmp/$RF" ] && ENSURE_REMOVED "/tmp/$RF"
done

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop
