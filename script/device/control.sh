#!/bin/sh

. /opt/muos/script/var/func.sh

CONTROL_DIR="/opt/muos/script/control"

START_CONTROL() {
	NAME="$1"
	CONTROL_SCRIPT="$CONTROL_DIR/$NAME.sh"

	[ -x "$CONTROL_SCRIPT" ] || return 0
	pgrep -f "$CONTROL_SCRIPT" >/dev/null 2>&1 && return 0

	"$CONTROL_SCRIPT" </dev/null >/dev/null 2>&1 &
}

CONTROLS="drastic gamecontrollerdb mupen64plus openbor ppsspp retroarch yabasanshiro"
[ "$(GET_VAR "device" "board/stick")" -gt 0 ] && CONTROLS="$CONTROLS playstation"

for CONTROL in $CONTROLS; do
	START_CONTROL "$CONTROL"
done
