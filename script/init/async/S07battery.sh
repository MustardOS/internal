#!/bin/sh

. /opt/muos/script/var/func.sh

BATTERY_USAGE_SCRIPT="/opt/muos/script/system/battery.sh"
WATCHER_PID_FILE="$MUOS_RUN_DIR/battery_usage/watcher.pid"

DO_START() {
	LOG_INFO "$0" 0 "BATTERY_USAGE" "Starting battery usage tracker"
	"$BATTERY_USAGE_SCRIPT" init
}

DO_STOP() {
	LOG_INFO "$0" 0 "BATTERY_USAGE" "Stopping battery usage tracker"
	"$BATTERY_USAGE_SCRIPT" shutdown

	if [ -f "$WATCHER_PID_FILE" ]; then
		WPID=$(cat "$WATCHER_PID_FILE" 2>/dev/null)
		if [ -n "$WPID" ]; then
			kill "$WPID" 2>/dev/null
		fi
		rm -f "$WATCHER_PID_FILE"
	fi
}

case "$1" in
	start)
		DO_START
		;;
	stop)
		DO_STOP
		;;
	restart)
		DO_STOP
		DO_START
		;;
	*)
		printf "Usage: %s {start|stop|restart}\n" "$0" >&2
		exit 1
		;;
esac
