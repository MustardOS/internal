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

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

if [ "$(echo "$FILE" | awk -F. '{print $NF}')" = "zip" ]; then
	nice --20 retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/$CORE" "$FILE" &
	RA_PID=$!

	rm -Rf "$FILE.save"
else
	F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')
	ERPC=$(sed <"$FILE.cfg" 's/[[:space:]]*$//')

	if [ -d "$F_PATH/.$NAME" ]; then
		SUBFOLDER=".$NAME"
	else
		SUBFOLDER="$NAME"
	fi

	nice --20 retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/easyrpg_libretro.so" "$F_PATH/$SUBFOLDER/$ERPC" &
	RA_PID=$!
fi

wait $RA_PID
unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop
