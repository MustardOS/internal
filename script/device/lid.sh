#!/bin/sh

. /opt/muos/script/var/func.sh

QUIT_LID_PROC="$MUOS_RUN_DIR/quit_lid_proc"
PID_FILE="$MUOS_RUN_DIR/lid.pid"

HALL_KEY="/sys/class/power_supply/axp2202-battery/hallkey"

LID_ENABLE=0
HALL_STATE=1

IS_RUNNING() {
	[ -f "$PID_FILE" ] || return 1
	read -r PID <"$PID_FILE" 2>/dev/null || return 1
	[ -n "${PID:-}" ] || return 1
	kill -0 "$PID" 2>/dev/null
}

START() {
	# If already running, do nothing!
	IS_RUNNING && exit 0

	rm -f "$PID_FILE" 2>/dev/null
	setsid -f "$0" run </dev/null >/dev/null 2>&1

	exit 0
}

READ_CONF() {
	LID_ENABLE="$(GET_VAR "config" "settings/advanced/lidswitch" 2>/dev/null || echo 0)"
}

READ_HALL() {
	# 1 = open, 0 = closed
	[ -r "$HALL_KEY" ] && read -r HALL_STATE <"$HALL_KEY" 2>/dev/null || HALL_STATE=1
}

RUN() {
	printf '%s\n' "$$" >"$PID_FILE"

	[ -r "$HALL_KEY" ] || while :; do
		[ -e "$QUIT_LID_PROC" ] && exit 0
		sleep 5
	done

	READ_CONF
	TICK=0

	READ_HALL
	LAST_STATE="$HALL_STATE"

	while :; do
		[ -e "$QUIT_LID_PROC" ] && exit 0

		TICK=$((TICK + 1))
		if [ "$TICK" -ge 5 ]; then
			READ_CONF
			TICK=0
		fi

		READ_HALL

		if [ "${LID_ENABLE:-0}" -eq 1 ] && [ "$HALL_STATE" = 0 ] && [ "$LAST_STATE" = 1 ]; then
			/opt/muos/script/system/suspend.sh
		fi

		LAST_STATE="$HALL_STATE"

		sleep "1"
	done
}

case "${1:-start}" in
	start) START ;;
	run) RUN ;;
	*)
		printf "Usage: %s {start | run}\n" "$0"
		exit 1
		;;
esac
