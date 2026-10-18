#!/bin/sh

[ -n "${MUOS_SERVICE_LOADED-}" ] && return 0
MUOS_SERVICE_LOADED=1
[ -n "${MUOS_CONFIG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/config.sh"

MESSAGE_EXEC="/opt/muos/frontend/muxmessage"
MESSAGE_TEXT="/tmp/msg_livetext"
MESSAGE_PROG="/tmp/msg_progress"
SAFE_QUIT="$MUOS_RUN_DIR/safe_quit"

ENSURE_REMOVED() {
	(
		P="$1"
		C=0

		while [ -e "$P" ] && [ "$C" -lt 10 ]; do
			rm -f -- "$P" 2>/dev/null

			[ -e "$P" ] || break

			C=$((C + 1))
			sleep 0.1
		done
	) &
}

GET_FRONTEND_PIDS() {
	pgrep -f 'muxfrontend|frontend\.sh' 2>/dev/null
}

FRONTEND_RUNNING() {
	PIDS="$(GET_FRONTEND_PIDS)"
	[ -n "$PIDS" ]
}

SIGNAL_FRONTEND() {
	SIG="$1"
	PIDS="$(GET_FRONTEND_PIDS)"

	[ -z "$PIDS" ] && return 0

	for PID in $PIDS; do
		kill "-$SIG" "$PID" 2>/dev/null
	done
}

FRONTEND() {
	case "${1:-}" in
		stop)
			[ -n "$SAFE_QUIT" ] && { : >"$SAFE_QUIT" 2>/dev/null; }

			SIGNAL_FRONTEND USR1

			I=25
			while FRONTEND_RUNNING && [ "$I" -gt 0 ]; do
				sleep 0.2
				I=$((I - 1))
			done

			if FRONTEND_RUNNING; then
				SIGNAL_FRONTEND TERM

				J=15
				while FRONTEND_RUNNING && [ "$J" -gt 0 ]; do
					sleep 0.2
					J=$((J - 1))
				done
			fi

			if FRONTEND_RUNNING; then
				SIGNAL_FRONTEND KILL

				K=20
				while FRONTEND_RUNNING && [ "$K" -gt 0 ]; do
					sleep 0.1
					K=$((K - 1))
				done
			fi
			;;
		start)
			if FRONTEND_RUNNING; then
				return 0
			fi

			if [ -n "${2:-}" ]; then
				setsid -f /opt/muos/script/mux/frontend.sh "$2" </dev/null >/dev/null 2>&1
			else
				setsid -f /opt/muos/script/mux/frontend.sh </dev/null >/dev/null 2>&1
			fi
			;;
		restart)
			FRONTEND stop

			if [ -n "${2:-}" ]; then
				FRONTEND start "$2"
			else
				FRONTEND start
			fi
			;;
		*)
			printf "Usage: FRONTEND start [module] | stop | restart [module]\n"
			return 1
			;;
	esac
}

HOTKEY() {
	case "$1" in
		stop)
			rm -f "$IDLE_STATE" 2>/dev/null
			/opt/muos/script/var/process.sh stop hotkey
			;;
		start)
			/opt/muos/script/var/process.sh start hotkey /opt/muos/script/mux/hotkey.sh
			;;
		restart)
			HOTKEY stop
			HOTKEY start
			;;
		*)
			printf "Usage: HOTKEY start | stop | restart\n"
			return 1
			;;
	esac
}

BATTERY() {
	case "$1" in
		stop) /opt/muos/script/var/process.sh stop battery ;;
		start)
			BATTERY_CAPACITY=$(GET_VAR "device" "battery/capacity")
			BATTERY_VOLTAGE=$(GET_VAR "device" "battery/voltage")
			[ -n "$BATTERY_CAPACITY" ] || [ -n "$BATTERY_VOLTAGE" ] || return 0
			/opt/muos/script/var/process.sh start battery /opt/muos/frontend/mubattery
			;;
		restart)
			BATTERY stop
			BATTERY start
			;;
		*)
			printf "Usage: BATTERY start | stop | restart\n"
			return 1
			;;
	esac
}

DIRECTLINK() {
	case "$1" in
		stop)
			/opt/muos/script/var/process.sh stop directlink
			rm -f "$MUOS_RUN_DIR/network/link"
			;;
		start)
			/opt/muos/script/var/process.sh start directlink /opt/muos/frontend/mulink
			;;
		restart)
			DIRECTLINK stop
			DIRECTLINK start
			;;
		*)
			printf "Usage: DIRECTLINK start | stop | restart\n"
			return 1
			;;
	esac
}

CAFFEINE() {
	DRINK="$MUOS_RUN_DIR/caffeine"

	case "${1:-}" in
		on)
			: >"$DRINK"
			;;
		off)
			rm -f "$DRINK" 2>/dev/null
			;;
		toggle)
			if [ -f "$DRINK" ]; then
				rm -f "$DRINK" 2>/dev/null
			else
				: >"$DRINK"
			fi
			;;
		status)
			[ -f "$DRINK" ] && return 0 || return 1
			;;
		*)
			printf "Usage: CAFFEINE on | off | toggle | status\n"
			return 1
			;;
	esac
}

MUXCTL() {
	case "${1:-}" in
		stop)
			HOTKEY stop
			FRONTEND stop
			BATTERY stop
			;;
		start)
			HOTKEY start &
			MUXCTL_HOTKEY_PID=$!

			BATTERY start &
			MUXCTL_BATTERY_PID=$!

			MUXCTL_RESULT=0

			wait "$MUXCTL_HOTKEY_PID" || MUXCTL_RESULT=1

			if [ -n "${2:-}" ]; then
				FRONTEND start "$2" || MUXCTL_RESULT=1
			else
				FRONTEND start || MUXCTL_RESULT=1
			fi

			wait "$MUXCTL_BATTERY_PID" || MUXCTL_RESULT=1
			return "$MUXCTL_RESULT"
			;;
		restart)
			MUXCTL stop

			if [ -n "${2:-}" ]; then
				MUXCTL start "$2"
			else
				MUXCTL start
			fi
			;;
		*)
			printf "Usage: MUXCTL start [module] | stop | restart [module]\n"
			return 1
			;;
	esac
}

MESSAGE() {
	case "$1" in
		stop)
			if /opt/muos/script/var/process.sh status message; then
				[ -f "$MESSAGE_TEXT" ] && rm -f "$MESSAGE_TEXT" "$MESSAGE_PROG"
				/opt/muos/script/var/process.sh stop message
			fi
			;;
		start)
			/opt/muos/script/var/process.sh status message && return 0
			[ ! -f "$MESSAGE_TEXT" ] && touch "$MESSAGE_TEXT"
			/opt/muos/script/var/process.sh start message "$MESSAGE_EXEC" 0 "" -l "$MESSAGE_TEXT"
			;;
		restart)
			MESSAGE stop
			MESSAGE start
			;;
		*)
			printf "Usage: MESSAGE start | stop | restart\n"
			return 1
			;;
	esac
}
