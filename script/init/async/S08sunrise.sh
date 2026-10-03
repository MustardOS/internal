#!/bin/sh

[ -n "$MUOS_FUNC_LOADED" ] || . /opt/muos/script/var/func.sh

case "${1:-start}" in
	start | restart) IN_SAFE_MODE && exit 0 ;;
esac

PID_FILE="$MUOS_RUN_DIR/sunrise.pid"

IS_RUNNING() {
	[ -f "$PID_FILE" ] || return 1
	_PID=$(cat "$PID_FILE" 2>/dev/null)
	[ -n "$_PID" ] && kill -0 "$_PID" 2>/dev/null
}

APPLY_TEMP() {
	COLOUR_DEV=$(GET_VAR "device" "screen/colour")
	[ -n "$COLOUR_DEV" ] && [ -e "$COLOUR_DEV" ] && printf "%s" "$1" >"$COLOUR_DEV"
}

APPLY_TEMP_BOOT() {
	COLOUR_DEV=$(GET_VAR "device" "screen/colour")
	[ -n "$COLOUR_DEV" ] && [ -e "$COLOUR_DEV" ] || return
	START_TEMP=$(cat "$COLOUR_DEV" 2>/dev/null)
	TARGET_TEMP=$1
	case "$START_TEMP:$TARGET_TEMP" in
		*[!0-9:-]*) APPLY_TEMP "$TARGET_TEMP"; return ;;
	esac
	STEP=1
	while [ "$STEP" -le 16 ]; do
		TEMP=$((START_TEMP + (TARGET_TEMP - START_TEMP) * STEP / 16))
		printf "%s" "$TEMP" >"$COLOUR_DEV"
		STEP=$((STEP + 1))
		sleep 0.04
	done
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

	TIME_HOUR=$(date +%H)
	TIME_MINUTE=$(date +%M)

	TIME_HOUR=${TIME_HOUR#0}
	TIME_MINUTE=${TIME_MINUTE#0}

	: "${TIME_HOUR:=0}"
	: "${TIME_MINUTE:=0}"

	TIME_NOW=$((TIME_HOUR * 60 + TIME_MINUTE))

	if [ "$TIME_NOW" -ge "$SUNRISE_SEC" ] && [ "$TIME_NOW" -lt "$SUNSET_SEC" ]; then
		printf "%s" "$SUNRISE_TEMP"
	else
		printf "%s" "$SUNSET_TEMP"
	fi
}

DAEMON_LOOP() {
	if [ "${1:-0}" = "1" ]; then
		APPLY_TEMP_BOOT "$(CURRENT_TEMP)"
	else
		APPLY_TEMP "$(CURRENT_TEMP)"
	fi
	while true; do
		sleep 60
		APPLY_TEMP "$(CURRENT_TEMP)"
	done
}

DO_START() {
	SCHEDULE_MODE=$(GET_VAR "config" "settings/colour/schedule_mode")
	if [ "${SCHEDULE_MODE:-0}" = "1" ]; then
		if IS_RUNNING; then
			kill "$_PID" 2>/dev/null
			rm -f "$PID_FILE"
		fi
		SUNRISE_TEMP=$(GET_VAR "config" "settings/colour/sunrise_temp")
		if [ "${1:-0}" = "1" ]; then
			APPLY_TEMP_BOOT "${SUNRISE_TEMP:-30}"
		else
			APPLY_TEMP "${SUNRISE_TEMP:-30}"
		fi
		exit 0
	fi

	if IS_RUNNING; then
		echo "Sunrise already running"
		exit 0
	fi

	DAEMON_LOOP "${1:-0}" &
	printf "%s\n" "$!" >"$PID_FILE"
}

DO_STOP() {
	if IS_RUNNING; then
		kill "$_PID" 2>/dev/null
		rm -f "$PID_FILE"
	else
		echo "Sunrise not running"
	fi
	SUNRISE_TEMP=$(GET_VAR "config" "settings/colour/sunrise_temp")
	APPLY_TEMP "${SUNRISE_TEMP:-30}"
}

case "$1" in
	start) DO_START 1 ;;
	stop) DO_STOP ;;
	restart)
		DO_STOP
		DO_START 0
		;;
	*)
		printf "Usage: %s {start|stop|restart}\n" "$0" >&2
		exit 1
		;;
esac
