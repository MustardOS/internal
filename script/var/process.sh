#!/bin/sh

PROCESS_ROOT="${MUOS_PROCESS_ROOT:-/run/muos/process}"

PROCESS_NAME_VALID() {
	case "$1" in "" | *[!A-Za-z0-9_.-]*) return 1 ;; esac
}

PROCESS_PATH() {
	PROCESS_NAME_VALID "$1" || return 1
	printf '%s/%s.pid\n' "$PROCESS_ROOT" "$1"
}

PROCESS_READ() {
	PR_PATH=$(PROCESS_PATH "$1") || return 1
	[ -r "$PR_PATH" ] || return 1
	PR_PID=$(sed -n '1p' "$PR_PATH" 2>/dev/null)
	PR_START=$(sed -n '2p' "$PR_PATH" 2>/dev/null)
	case "$PR_PID:$PR_START" in *[!0-9:]* | *::* | :* | *:) rm -f "$PR_PATH"; return 1 ;; esac
	PR_CURRENT=$(awk '{print $22}' "/proc/$PR_PID/stat" 2>/dev/null)
	if [ -z "$PR_CURRENT" ] || [ "$PR_CURRENT" != "$PR_START" ]; then
		rm -f "$PR_PATH"
		return 1
	fi
	return 0
}

PROCESS_REGISTER() {
	PROCESS_NAME_VALID "$1" || return 1
	PREG_PID="${2:-$$}"
	case "$PREG_PID" in "" | *[!0-9]*) return 1 ;; esac
	PREG_START=$(awk '{print $22}' "/proc/$PREG_PID/stat" 2>/dev/null)
	case "$PREG_START" in "" | *[!0-9]*) return 1 ;; esac
	mkdir -p "$PROCESS_ROOT" || return 1
	chmod 700 "$PROCESS_ROOT" || return 1
	PREG_PATH=$(PROCESS_PATH "$1") || return 1
	PREG_TMP=$(mktemp "$PROCESS_ROOT/.${1}.XXXXXX") || return 1
	if ! printf '%s\n%s\n' "$PREG_PID" "$PREG_START" >"$PREG_TMP" || ! chmod 600 "$PREG_TMP" ||
		! mv -f "$PREG_TMP" "$PREG_PATH"; then
		rm -f "$PREG_TMP"
		return 1
	fi
}

PROCESS_REMOVE() {
	PREM_PATH=$(PROCESS_PATH "$1") || return 1
	if [ -n "${2:-}" ] && [ -r "$PREM_PATH" ]; then
		PREM_PID=$(sed -n '1p' "$PREM_PATH" 2>/dev/null)
		[ "$PREM_PID" = "$2" ] || return 0
	fi
	rm -f "$PREM_PATH"
}

PROCESS_ACQUIRE_START_LOCK() {
	PAL_PATH="$PROCESS_ROOT/.${1}.lock"
	if mkdir "$PAL_PATH" 2>/dev/null; then
		:
	else
		PAL_PID=$(sed -n '1p' "$PAL_PATH/owner" 2>/dev/null)
		PAL_START=$(sed -n '2p' "$PAL_PATH/owner" 2>/dev/null)
		case "$PAL_PID:$PAL_START" in
			*[!0-9:]* | *::* | :* | *:) PAL_CURRENT="" ;;
			*) PAL_CURRENT=$(awk '{print $22}' "/proc/$PAL_PID/stat" 2>/dev/null) ;;
		esac
		[ -n "$PAL_CURRENT" ] && [ "$PAL_CURRENT" = "$PAL_START" ] && return 1
		rm -f "$PAL_PATH/owner" 2>/dev/null
		rmdir "$PAL_PATH" 2>/dev/null || return 1
		mkdir "$PAL_PATH" 2>/dev/null || return 1
	fi
	PAL_SELF_START=$(awk '{print $22}' "/proc/$$/stat" 2>/dev/null) || {
		rmdir "$PAL_PATH" 2>/dev/null
		return 1
	}
	if ! printf '%s\n%s\n' "$$" "$PAL_SELF_START" >"$PAL_PATH/owner"; then
		rmdir "$PAL_PATH" 2>/dev/null
		return 1
	fi
}

PROCESS_RELEASE_START_LOCK() {
	PRL_PATH="$PROCESS_ROOT/.${1}.lock"
	rm -f "$PRL_PATH/owner" 2>/dev/null
	rmdir "$PRL_PATH" 2>/dev/null
}

PROCESS_START() {
	PSTART_NAME="$1"
	shift
	PROCESS_NAME_VALID "$PSTART_NAME" || return 1
	[ "$#" -gt 0 ] || return 1
	PROCESS_READ "$PSTART_NAME" && return 0
	mkdir -p "$PROCESS_ROOT" || return 1
	PROCESS_ACQUIRE_START_LOCK "$PSTART_NAME" || {
		PSTART_WAIT=0
		while [ "$PSTART_WAIT" -lt 20 ]; do
			PROCESS_READ "$PSTART_NAME" && return 0
			sleep 0.1
			PSTART_WAIT=$((PSTART_WAIT + 1))
		done
		return 1
	}
	trap 'PROCESS_RELEASE_START_LOCK "$PSTART_NAME"' EXIT
	trap 'exit 1' HUP INT TERM
	PROCESS_READ "$PSTART_NAME" && return 0
	setsid -f "$0" run "$PSTART_NAME" "$@" </dev/null >/dev/null 2>&1 || return 1
	PSTART_WAIT=0
	while [ "$PSTART_WAIT" -lt 20 ]; do
		PROCESS_READ "$PSTART_NAME" && return 0
		sleep 0.1
		PSTART_WAIT=$((PSTART_WAIT + 1))
	done
	return 1
}

PROCESS_STOP() {
	PSTOP_NAME="$1"
	PSTOP_GROUP="${2:-0}"
	PROCESS_READ "$PSTOP_NAME" || return 0
	PSTOP_PID="$PR_PID"
	if [ "$PSTOP_GROUP" -eq 1 ]; then
		if ! kill -TERM -- "-$PSTOP_PID" 2>/dev/null; then :; fi
		PSTOP_WAIT=0
		while kill -0 -- "-$PSTOP_PID" 2>/dev/null && [ "$PSTOP_WAIT" -lt 25 ]; do
			sleep 0.2
			PSTOP_WAIT=$((PSTOP_WAIT + 1))
		done
		if kill -0 -- "-$PSTOP_PID" 2>/dev/null; then
			if ! kill -KILL -- "-$PSTOP_PID" 2>/dev/null; then :; fi
			PSTOP_WAIT=0
			while kill -0 -- "-$PSTOP_PID" 2>/dev/null && [ "$PSTOP_WAIT" -lt 5 ]; do
				sleep 0.2
				PSTOP_WAIT=$((PSTOP_WAIT + 1))
			done
		fi
		PROCESS_REMOVE "$PSTOP_NAME" "$PSTOP_PID"
		! kill -0 -- "-$PSTOP_PID" 2>/dev/null
		return
	else
		if ! kill -TERM "$PSTOP_PID" 2>/dev/null; then :; fi
	fi
	PSTOP_WAIT=0
	while [ "$PSTOP_WAIT" -lt 25 ]; do
		PROCESS_READ "$PSTOP_NAME" || return 0
		sleep 0.2
		PSTOP_WAIT=$((PSTOP_WAIT + 1))
	done
	PROCESS_READ "$PSTOP_NAME" || return 0
	if ! kill -KILL "$PR_PID" 2>/dev/null; then :; fi
	PSTOP_WAIT=0
	while [ "$PSTOP_WAIT" -lt 5 ]; do
		PROCESS_READ "$PSTOP_NAME" || return 0
		sleep 0.2
		PSTOP_WAIT=$((PSTOP_WAIT + 1))
	done
	return 1
}

PROCESS_SIGNAL() {
	case "$2" in HUP | INT | TERM | KILL | USR1 | USR2) ;; *) return 1 ;; esac
	PROCESS_READ "$1" || return 1
	kill "-$2" "$PR_PID" 2>/dev/null
}

COMMAND="${1:-}"
case "$COMMAND" in
	start)
		shift
		PROCESS_START "$@"
		;;
	run)
		shift
		RUN_NAME="$1"
		shift
		[ "$#" -gt 0 ] || exit 1
		PROCESS_REGISTER "$RUN_NAME" "$$" || exit 1
		exec "$@"
		;;
	stop)
		PROCESS_STOP "${2:-}"
		;;
	stop-group)
		PROCESS_STOP "${2:-}" 1
		;;
	status)
		PROCESS_READ "${2:-}"
		;;
	pid)
		PROCESS_READ "${2:-}" || exit 1
		printf '%s\n' "$PR_PID"
		;;
	signal)
		PROCESS_SIGNAL "${2:-}" "${3:-}"
		;;
	register)
		PROCESS_REGISTER "${2:-}" "${3:-$$}"
		;;
	remove)
		PROCESS_REMOVE "${2:-}" "${3:-}"
		;;
	*)
		printf 'Usage: %s <start|stop|stop-group|status|pid|signal|register|remove> name [command...]\n' "$0" >&2
		exit 1
		;;
esac
