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

if echo "$CORE" | grep -qE "flycast|morpheuscast"; then
	export SDL_NO_SIGNAL_HANDLERS=1
fi

if echo "$CORE" | grep -q "j2me"; then
	export JAVA_HOME=/opt/java
	PATH=$PATH:$JAVA_HOME/bin
fi

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

nice --20 retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/$CORE" "$FILE"

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop
