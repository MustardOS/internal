#!/bin/sh

. /opt/muos/script/var/func.sh

PROC="$(GET_VAR config system/foreground_process)"

case "$PROC" in
	mux*) exit 0 ;;
	*[!0-9]* | "") PIDS="$(pgrep -x "$PROC" 2>/dev/null)" ;;
	*) PIDS="$PROC" ;;
esac

[ -z "$PIDS" ] && exit 1

# Die bart die
for PID in $PIDS; do
	kill -9 "$PID" 2>/dev/null
done
