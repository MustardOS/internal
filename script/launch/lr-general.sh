#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)
IS_SWAP=$(DETECT_CONTROL_SWAP)

if echo "$CORE" | grep -qE "flycast|morpheuscast"; then
	export SDL_NO_SIGNAL_HANDLERS=1
fi

if echo "$CORE" | grep -q "j2me"; then
	export JAVA_HOME=/opt/java
	PATH=$PATH:$JAVA_HOME/bin
fi

set -- -v -f
[ -n "$RA_ARGS" ] && set -- "$@" "$RA_ARGS"
retroarch "$@" -L "$MUOS_SHARE_DIR/core/$CORE" "$FILE"

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
