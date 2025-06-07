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

RA_CONF="/run/muos/storage/info/config/retroarch.cfg"
CONFIGURE_RETROARCH "$RA_CONF"

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')
if [ -d "$F_PATH/.$NAME" ]; then
	SUBFOLDER=".$NAME"
else
	SUBFOLDER="$NAME"
fi

SCVM="$F_PATH/$SUBFOLDER/$NAME.scummvm"
cp "$F_PATH/$NAME.scummvm" "$SCVM"

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

nice --20 retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/scummvm_libretro.so" "$SCVM" &
RA_PID=$!

wait $RA_PID
unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop
