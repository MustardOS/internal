#!/bin/sh

[ -n "${MUOS_RUNTIME_LOADED-}" ] && return 0
MUOS_RUNTIME_LOADED=1
[ -n "${MUOS_LOG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/log.sh"

GPTOKEYB() {
	PM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
	GPTOKEYB_DIR="$MUOS_SHARE_DIR/emulator/gptokeyb"

	if [ -f "$GPTOKEYB_DIR/$2.gptk" ]; then
		LIB_IPOSE="libinterpose.aarch64.so"
		ln -sf "$PM_DIR/$LIB_IPOSE" "/usr/lib/$LIB_IPOSE" >/dev/null 2>&1
		if ! /opt/muos/script/var/process.sh stop-group gptokeyb >/dev/null 2>&1; then
			LOG_WARN "$0" 0 "INPUT" "The previous gptokeyb process did not stop cleanly"
		fi
		/opt/muos/script/var/process.sh start gptokeyb \
			"$PM_DIR/gptokeyb2" "$1" -c "$GPTOKEYB_DIR/$2.gptk"
	fi
}

TERMINATE_SYNCTHING() {
	if [ "$(GET_VAR "config" "web/syncthing")" -eq 1 ]; then
		LOG_INFO "$0" 0 "HALT" "Shutdown Syncthing gracefully"
		SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$MUOS_STORE_DIR/syncthing/config.xml")
		SYNCTHING_PORT=$(GET_WEB_PORT "syncthing_port" 7070)
		CURL_OUTPUT=$(
			curl -s --connect-timeout 1 --max-time 2 -o /dev/null -w "%{http_code}" \
				-X POST -H "X-API-Key: $SYNCTHING_API" \
				"http://localhost:$SYNCTHING_PORT/rest/system/shutdown"
		)
		[ "$CURL_OUTPUT" -eq 200 ] && LOG_INFO "$0" 0 "HALT" "Syncthing shutdown request sent successfully"
	fi
}

GET_WEB_PORT() {
	WEB_PORT_VALUE=$(GET_VAR "config" "web/$1")
	case "$WEB_PORT_VALUE" in
		'' | *[!0-9]*) WEB_PORT_VALUE="$2" ;;
		*)
			if [ "${#WEB_PORT_VALUE}" -gt 5 ] || [ "$WEB_PORT_VALUE" -lt 1 ] || [ "$WEB_PORT_VALUE" -gt 65535 ]; then
				WEB_PORT_VALUE="$2"
			fi
			;;
	esac
	printf '%s\n' "$WEB_PORT_VALUE"
}

LOG_CLEANER() {
	LOG_DIR="$(GET_VAR "device" "storage/rom/mount")"
	DAYS=7

	find "$LOG_DIR" -type f -name '*.log' -mtime +"$DAYS" -exec rm -f -- {} +
}

SAVE_CPU_GOV() {
	GOV_PATH="${1:-$(GET_VAR "device" "cpu/governor")}"
	GOV_WAKE="${2:-"$MUOS_RUN_DIR/wake_cpu_gov"}"

	read -r GOV <"$GOV_PATH" || return 1
	GOV=${GOV%%[[:space:]]*}

	[ -n "$GOV" ] || return 1

	printf "%s" "$GOV" >"$GOV_WAKE"
}

RESTORE_CPU_GOV() {
	GOV_PATH="${1:-$(GET_VAR "device" "cpu/governor")}"
	GOV_WAKE="${2:-"$MUOS_RUN_DIR/wake_cpu_gov"}"

	[ -f "$GOV_WAKE" ] || return 1

	read -r GOV <"$GOV_WAKE"
	GOV=${GOV%%[[:space:]]*}

	i=0
	while [ ! -w "$GOV_PATH" ] && [ $i -lt 30 ]; do
		sleep 0.05
		i=$((i + 1))
	done

	if [ -n "$GOV" ] && [ -w "$GOV_PATH" ]; then
		printf "%s" "$GOV" >"$GOV_PATH"
	fi
}

IS_MUXTERM() {
	COMM=
	read -r COMM </proc/$PPID/comm 2>/dev/null
	[ "$COMM" = "muxterm" ]
}

ACT_GO="${ACT_GO:-$MUOS_RUN_DIR/action}"
APP_GO="${APP_GO:-$MUOS_RUN_DIR/application}"
GOV_GO="${GOV_GO:-$MUOS_RUN_DIR/governor}"
CON_GO="${CON_GO:-$MUOS_RUN_DIR/controller}"
FLT_GO="${FLT_GO:-$MUOS_RUN_DIR/filter}"
RAC_GO="${RAC_GO:-$MUOS_RUN_DIR/retroarch}"
ROM_GO="${ROM_GO:-$MUOS_RUN_DIR/content}"
SAA_GO="${SAA_GO:-$MUOS_RUN_DIR/auto_core}"
SAG_GO="${SAG_GO:-$MUOS_RUN_DIR/auto_governor}"
SAR_GO="${SAR_GO:-$MUOS_RUN_DIR/auto_retroarch}"
SHD_GO="${SHD_GO:-$MUOS_RUN_DIR/shader}"
OVL_GO="${OVL_GO:-$MUOS_RUN_DIR/overlay}"
OVO_GO="${OVO_GO:-$MUOS_RUN_DIR/overlay_options}"
EX_CARD="${EX_CARD:-/tmp/explore_card}"

SAFE_WRITE() {
	printf '%s\n' "$1" >"$2"
}

BOOT_STATE_DIR="$MUOS_CONF_SYSTEM/boot"
BOOT_ATTEMPT_KEY="boot/attempt_count"
SAFE_MODE_FLAG="$MUOS_RUN_DIR/safe_mode"
BOOT_CONFIRMED_FLAG="$MUOS_RUN_DIR/boot_confirmed"
SAFE_MODE_THRESHOLD=3
BOOT_CONFIRM_GRACE=8
FRONTEND_BIN="/opt/muos/frontend/muxfrontend"
LAUNCH_SCRIPT="/opt/muos/script/mux/launch.sh"

export SAFE_MODE_FLAG BOOT_CONFIRMED_FLAG FRONTEND_BIN LAUNCH_SCRIPT

IN_SAFE_MODE() {
	[ -e "$SAFE_MODE_FLAG" ]
}

BOOT_GUARD_ARM() {
	mkdir -p "$BOOT_STATE_DIR" "$MUOS_RUN_DIR" 2>/dev/null

	BOOT_COUNT=
	[ -r "$BOOT_STATE_DIR/attempt_count" ] && {
		IFS= read -r BOOT_COUNT <"$BOOT_STATE_DIR/attempt_count" 2>/dev/null
	}

	case "$BOOT_COUNT" in
		'' | *[!0-9]*) BOOT_COUNT=0 ;;
	esac

	BOOT_COUNT=$((BOOT_COUNT + 1))

	SET_VAR_DURABLE "system" "$BOOT_ATTEMPT_KEY" "$BOOT_COUNT" || return 0

	if [ "$BOOT_COUNT" -ge "$SAFE_MODE_THRESHOLD" ]; then
		: >"$SAFE_MODE_FLAG" 2>/dev/null

		SET_VAR_DURABLE "system" "$BOOT_ATTEMPT_KEY" "0"

		LOG_WARN "$0" 0 "BOOTING" "$(printf "Boot attempt %s with no confirmed frontend, this boot is safe mode" "$BOOT_COUNT")"
	else
		rm -f "$SAFE_MODE_FLAG" 2>/dev/null
	fi
}

BOOT_GUARD_CONFIRM() {
	SET_VAR_DIRECT "system" "$BOOT_ATTEMPT_KEY" "0"
	rm -f "$SAFE_MODE_FLAG" 2>/dev/null
	: >"$BOOT_CONFIRMED_FLAG" 2>/dev/null
	LOG_INFO "$0" 0 "BOOTING" "Frontend confirmed good, boot counter cleared"
}

BOOT_CONFIRMED() {
	[ -e "$BOOT_CONFIRMED_FLAG" ]
}

BOOT_GUARD_CONFIRM_LATER() {
	(
		WATCH_PID=
		STABLE_SECONDS=0

		while [ "$STABLE_SECONDS" -lt "$BOOT_CONFIRM_GRACE" ]; do
			sleep 1

			NOW_PID=$(pgrep -f "$FRONTEND_BIN" 2>/dev/null | head -n 1)

			if [ -z "$NOW_PID" ]; then
				WATCH_PID=
				STABLE_SECONDS=0
				continue
			fi

			if [ -z "$WATCH_PID" ]; then
				WATCH_PID="$NOW_PID"
			elif [ "$NOW_PID" != "$WATCH_PID" ]; then
				LOG_INFO "$0" 0 "BOOTING" "Frontend changed inside grace window, restarting stability check"
				WATCH_PID="$NOW_PID"
				STABLE_SECONDS=0
				continue
			fi

			STABLE_SECONDS=$((STABLE_SECONDS + 1))
		done

		BOOT_GUARD_CONFIRM
	) &
}

WATCHDOG_START() {
	WATCHDOG_DEV="/dev/watchdog"
	WATCHDOG_TIMEOUT=60

	[ -e "$WATCHDOG_DEV" ] || return 0
	pgrep -f "watchdog.*$WATCHDOG_DEV" >/dev/null 2>&1 && return 0

	if command -v watchdog >/dev/null 2>&1; then
		watchdog -T "$WATCHDOG_TIMEOUT" -t "$((WATCHDOG_TIMEOUT / 3))" "$WATCHDOG_DEV" 2>/dev/null
		return 0
	fi

	if command -v busybox >/dev/null 2>&1; then
		busybox watchdog -T "$WATCHDOG_TIMEOUT" -t "$((WATCHDOG_TIMEOUT / 3))" "$WATCHDOG_DEV" 2>/dev/null
		return 0
	fi

	(
		exec 9>"$WATCHDOG_DEV" 2>/dev/null || exit 0
		while :; do
			printf "\0" >&9 2>/dev/null || break
			sleep "$((WATCHDOG_TIMEOUT / 3))"
		done
	) &
}

MUOS_INIT_DEFERRED=""
export MUOS_INIT_DEFERRED

RUN_INIT_DEFERRED() {
	INIT_DEFER_DIR="${1:-/opt/muos/script/init/async}"

	[ -d "$INIT_DEFER_DIR" ] || return 0

	INIT_DEFER_WAIT=0
	while [ "$INIT_DEFER_WAIT" -lt 150 ]; do
		pgrep -f "$FRONTEND_BIN" >/dev/null 2>&1 && break
		pgrep -f "$LAUNCH_SCRIPT" >/dev/null 2>&1 && break
		sleep 0.1
		INIT_DEFER_WAIT=$((INIT_DEFER_WAIT + 1))
	done

	sleep "${MUOS_INIT_DEFER_SETTLE:-3}"

	for INIT_DEFER in $MUOS_INIT_DEFERRED; do
		[ -f "$INIT_DEFER_DIR/$INIT_DEFER" ] || continue
		(RUN_INIT_RECORDED start "$INIT_DEFER_DIR/$INIT_DEFER") >/dev/null 2>&1 &
	done

	wait
}

RUN_INIT_SCRIPT() {
	INIT_MODE=$1
	INIT_SCRIPT=$2

	[ -f "$INIT_SCRIPT" ] || return 0

	case "$INIT_SCRIPT" in
		*.sh)
			(
				trap - INT QUIT TSTP
				set "$INIT_MODE"
				# shellcheck disable=SC1090
				. "$INIT_SCRIPT"
			)
			;;
		*) "$INIT_SCRIPT" "$INIT_MODE" ;;
	esac
}

RUN_INIT_RECORDED() {
	INIT_MODE=$1
	INIT_SCRIPT=$2
	INIT_NAME=${INIT_SCRIPT##*/}
	INIT_STATUS_DIR="$MUOS_RUN_DIR/boot"
	INIT_STATUS_TMP="$INIT_STATUS_DIR/${INIT_MODE}_${INIT_NAME}.tmp.$$"
	INIT_STATUS_FILE="$INIT_STATUS_DIR/${INIT_MODE}_${INIT_NAME}.status"

	mkdir -p "$INIT_STATUS_DIR" || return 1
	read -r INIT_STARTED _ </proc/uptime || INIT_STARTED=0
	RUN_INIT_SCRIPT "$INIT_MODE" "$INIT_SCRIPT"
	INIT_RESULT=$?
	read -r INIT_FINISHED _ </proc/uptime || INIT_FINISHED=0
	printf 'start=%s\nfinish=%s\nstatus=%s\n' "$INIT_STARTED" "$INIT_FINISHED" "$INIT_RESULT" >"$INIT_STATUS_TMP"
	mv -f "$INIT_STATUS_TMP" "$INIT_STATUS_FILE"
	return "$INIT_RESULT"
}

RUN_INIT_DIR() {
	INIT_MODE=$1
	INIT_DIR=$2
	INIT_ORDER=${3:-forward}

	[ -d "$INIT_DIR" ] || return 0

	if [ "$INIT_ORDER" = "reverse" ]; then
		INIT_SCRIPTS=$(printf '%s\n' "$INIT_DIR"/S??* | sort -r)
	else
		INIT_SCRIPTS=$(printf '%s\n' "$INIT_DIR"/S??*)
	fi

	INIT_DIR_RESULT=0
	INIT_TOTAL=0

	for INIT_SCRIPT in $INIT_SCRIPTS; do
		[ -e "$INIT_SCRIPT" ] && INIT_TOTAL=$((INIT_TOTAL + 1))
	done

	INIT_DONE=0
	for INIT_SCRIPT in $INIT_SCRIPTS; do
		[ -e "$INIT_SCRIPT" ] || continue

		RUN_INIT_RECORDED "$INIT_MODE" "$INIT_SCRIPT" || INIT_DIR_RESULT=1
		INIT_DONE=$((INIT_DONE + 1))

		[ "$INIT_MODE" = "start" ] && [ "$INIT_TOTAL" -gt 0 ] &&
			BOOT_PROGRESS "$((INIT_DONE * 90 / INIT_TOTAL))"
	done
	return "$INIT_DIR_RESULT"
}

RUN_INIT_DIR_BOUNDED() {
	INIT_MODE=$1
	INIT_DIR=$2
	INIT_ORDER=${3:-forward}
	INIT_SKIP=${4:-}
	INIT_LIMIT=${MUOS_INIT_ASYNC_LIMIT:-3}

	case "$INIT_LIMIT" in
		'' | *[!0-9]*) INIT_LIMIT=3 ;;
	esac
	[ "$INIT_LIMIT" -ge 1 ] 2>/dev/null || INIT_LIMIT=1
	[ "$INIT_LIMIT" -le 8 ] 2>/dev/null || INIT_LIMIT=8
	[ -d "$INIT_DIR" ] || return 0

	if [ "$INIT_ORDER" = "reverse" ]; then
		INIT_SCRIPTS=$(printf '%s\n' "$INIT_DIR"/S??* | sort -r)
	else
		INIT_SCRIPTS=$(printf '%s\n' "$INIT_DIR"/S??*)
	fi

	INIT_PIDS=
	INIT_COUNT=0
	INIT_DIR_RESULT=0
	for INIT_SCRIPT in $INIT_SCRIPTS; do
		[ -e "$INIT_SCRIPT" ] || continue
		INIT_NAME=${INIT_SCRIPT##*/}

		INIT_SKIPPED=0
		for INIT_EXCLUDE in $INIT_SKIP; do
			[ "$INIT_NAME" = "$INIT_EXCLUDE" ] && INIT_SKIPPED=1 && break
		done
		[ "$INIT_SKIPPED" -eq 1 ] && continue
		(RUN_INIT_RECORDED "$INIT_MODE" "$INIT_SCRIPT") >/dev/null 2>&1 &
		INIT_PIDS="$INIT_PIDS $!"
		INIT_COUNT=$((INIT_COUNT + 1))

		if [ "$INIT_COUNT" -ge "$INIT_LIMIT" ]; then
			set -- $INIT_PIDS
			wait "$1" || INIT_DIR_RESULT=1
			shift

			INIT_PIDS="$*"
			INIT_COUNT=$((INIT_COUNT - 1))
		fi
	done

	for INIT_PID in $INIT_PIDS; do
		wait "$INIT_PID" || INIT_DIR_RESULT=1
	done
	return "$INIT_DIR_RESULT"
}
