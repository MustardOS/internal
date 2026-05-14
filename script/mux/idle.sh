#!/bin/sh

. /opt/muos/script/var/func.sh

INHIBIT_NONE=0
INHIBIT_BOTH=1
INHIBIT_SLEEP=2

PID_FILE="$MUOS_RUN_DIR/idle.pid"

IS_RUNNING() {
	[ -f "$PID_FILE" ] || return 1
	read -r PID <"$PID_FILE" 2>/dev/null || return 1
	[ -n "${PID:-}" ] || return 1
	kill -0 "$PID" 2>/dev/null
}

START() {
	# If already running, do nothing!
	IS_RUNNING && exit 0

	LOG_INFO "$0" 0 "IDLE" "Starting idle inhibitor watcher"
	rm -f "$PID_FILE" 2>/dev/null
	setsid -f "$0" run </dev/null >/dev/null 2>&1

	exit 0
}

RUN() {
	printf '%s\n' "$$" >"$PID_FILE"
	CHARGER_PATH="$(GET_VAR "device" "battery/charger")"

	LOG_INFO "$0" 0 "IDLE" "$(printf "Idle watcher running (PID: %s)" "$$")"

	LAST_INHIBIT=-1

	while :; do
		INHIBIT=$INHIBIT_NONE

		# Charging inhibits sleep (but allow display idle etc.)
		if [ -n "${CHARGER_PATH:-}" ] && [ -r "$CHARGER_PATH" ]; then
			CHARGING=0
			read -r CHARGING <"$CHARGER_PATH" 2>/dev/null || CHARGING=0
			[ "$CHARGING" -eq 1 ] && INHIBIT=$INHIBIT_SLEEP
		fi

		# Have a peek at all of the running processes and break
		# if one is matched from our watch list
		for PROC in /proc/[0-9]*/comm; do
			[ -r "$PROC" ] || continue
			P=
			read -r P <"$PROC" 2>/dev/null || continue

			case "$P" in
				mucredits | muterm | muxcharge | muxmessage)
					INHIBIT=$INHIBIT_BOTH
					break
					;;
			esac
		done

		if [ "$INHIBIT" -ne "$LAST_INHIBIT" ]; then
			LOG_DEBUG "$0" 0 "IDLE" "$(printf "Idle inhibit state changed: %s -> %s" "$LAST_INHIBIT" "$INHIBIT")"
			LAST_INHIBIT="$INHIBIT"
		fi

		SET_VAR "system" "idle_inhibit" "$INHIBIT"
		sleep 5
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
