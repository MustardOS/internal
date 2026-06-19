#!/bin/sh

. /opt/muos/script/var/func.sh

PID_FILE="$MUOS_RUN_DIR/sunrise.pid"

IS_RUNNING() {
	[ -f "$PID_FILE" ] && IFS= read -r _PID <"$PID_FILE" 2>/dev/null && kill -0 "$_PID" 2>/dev/null
}

APPLY_TEMP() {
	COLOUR_DEV=$(GET_VAR "device" "screen/colour")
	[ -n "$COLOUR_DEV" ] && [ -e "$COLOUR_DEV" ] && printf "%s" "$1" >"$COLOUR_DEV"
}

CURRENT_TEMP() {
	SUNRISE_TEMP=$(GET_VAR "config" "settings/colour/sunrise_temp")
	SUNSET_TEMP=$(GET_VAR "config" "settings/colour/sunset_temp")
	SUNRISE_TIME=$(GET_VAR "config" "settings/colour/sunrise_time")
	SUNSET_TIME=$(GET_VAR "config" "settings/colour/sunset_time")

	: "${SUNRISE_TEMP:=30}"
	: "${SUNSET_TEMP:=30}"
	: "${SUNRISE_TIME:=24}"
	: "${SUNSET_TIME:=72}"

	SUNRISE_SEC=$((SUNRISE_TIME * 15))
	SUNSET_SEC=$((SUNSET_TIME * 15))

	TIME=$(date +%H%M)
	TIME_HOUR=$(printf "%d" "${TIME%??}")
	TIME_MINUTE=$(printf "%d" "${TIME#??}")
	TIME_NOW=$((TIME_HOUR * 60 + TIME_MINUTE))

	if [ "$TIME_NOW" -ge "$SUNRISE_SEC" ] && [ "$TIME_NOW" -lt "$SUNSET_SEC" ]; then
		printf "%s" "$SUNRISE_TEMP"
	else
		printf "%s" "$SUNSET_TEMP"
	fi
}

DAEMON_LOOP() {
	while true; do
		APPLY_TEMP "$(CURRENT_TEMP)"
		sleep 60
	done
}

DO_START() {
	SCHEDULE_MODE=$(GET_VAR "config" "settings/colour/schedule_mode")
	if [ "${SCHEDULE_MODE:-0}" = "1" ]; then
		DO_STOP
		exit 0
	fi

	if IS_RUNNING; then
		echo "Sunrise already running"
		exit 0
	fi

	DAEMON_LOOP &
	printf "%s" "$!" >"$PID_FILE"
}

DO_STOP() {
	if IS_RUNNING; then
		IFS= read -r _PID <"$PID_FILE"
		kill "$_PID" 2>/dev/null
		rm -f "$PID_FILE"
	else
		echo "Sunrise not running"
	fi
}

case "$1" in
	start) DO_START ;;
	stop) DO_STOP ;;
	restart)
		DO_STOP
		DO_START
		;;
	*)
		printf "Usage: %s {start|stop|restart}\n" "$0" >&2
		exit 1
		;;
esac
