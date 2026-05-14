#!/bin/sh

. /opt/muos/script/var/func.sh

PROC="$(GET_VAR config system/foreground_process)"

LOG_DEBUG "$0" 0 "PROC_DIE" "$(printf "Resolving foreground process: '%s'" "$PROC")"

case "$PROC" in
	mux*) exit 0 ;;
	*[!0-9]* | "") PIDS="$(pgrep -f "$PROC" 2>/dev/null)" ;;
	*) PIDS="$PROC" ;;
esac

if [ -z "$PIDS" ]; then
	LOG_WARN "$0" 0 "PROC_DIE" "$(printf "No matching PIDs for '%s'" "$PROC")"
	exit 1
fi

# Die bart die
for PID in $PIDS; do
	LOG_INFO "$0" 0 "PROC_DIE" "$(printf "Killing PID %s ('%s')" "$PID" "$PROC")"
	kill -9 "$PID" 2>/dev/null
done
