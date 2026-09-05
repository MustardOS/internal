#!/bin/sh

. /opt/muos/script/var/func.sh

CONTROL_DIR="/opt/muos/script/control"

FORCE_COPY=0
[ "${1:-}" = "FORCE_COPY" ] && FORCE_COPY=1

CONTROL_PIDS=""
CONTROL_RESULT=0

START_CONTROL() {
	NAME="$1"
	CONTROL_SCRIPT="$CONTROL_DIR/$NAME.sh"

	[ -x "$CONTROL_SCRIPT" ] || return 0
	pgrep -f "$CONTROL_SCRIPT" >/dev/null 2>&1 && return 0

	if [ "$FORCE_COPY" -eq 1 ]; then
		"$CONTROL_SCRIPT" FORCE_COPY </dev/null >/dev/null 2>&1 &
	else
		"$CONTROL_SCRIPT" </dev/null >/dev/null 2>&1 &
	fi

	CONTROL_PIDS="$CONTROL_PIDS $!"
}

CONTROLS="drastic gamecontrollerdb mupen64plus openbor ppsspp retroarch task yabasanshiro"
[ "$(GET_VAR "device" "board/stick")" -gt 0 ] && CONTROLS="$CONTROLS playstation"

for CONTROL in $CONTROLS; do
	START_CONTROL "$CONTROL"
done

for CONTROL_PID in $CONTROL_PIDS; do
	wait "$CONTROL_PID" || CONTROL_RESULT=1
done

exit "$CONTROL_RESULT"
