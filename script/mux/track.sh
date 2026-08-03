#!/bin/sh

# The jq filters keep their single quotes on purpose, the dollar names in them
# belong to jq and are bound with `--arg` so any shell must leave britney alone!
# shellcheck disable=SC2016

. /opt/muos/script/var/func.sh

[ "$(GET_VAR "config" "settings/general/activity")" -eq 0 ] && exit 0

NAME=${1-}
CORE=${2-}
FILE=${3-}
ACTION=${4-}

TRACK_TAG="TRACK"
TRACK_JSON="$MUOS_STORE_DIR/info/track/playtime_data.json"
TRACK_DIR=${TRACK_JSON%/*}
TRACK_LOG="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/playtime_error.log"
TRACK_LOG_DIR=${TRACK_LOG%/*}
LOCK_DIR="$TRACK_DIR/.playtime.lock"
HIGHWATER_FILE="$TRACK_DIR/.time_highwater"
CURRENT_FILE="$TRACK_DIR/.current_session"
MIGRATION_MARKER="$TRACK_DIR/.union_path_migration_v2"

# Clock and session policy!
TIME_FLOOR=1735689600         # 2025-01-01 00:00:00 UTC
TIME_CEILING=4102444799       # 2099-12-31 23:59:59 UTC
TIME_BACKWARD_GRACE=300       # Permit a five minute backwards correction
CLOCK_DELTA_TOLERANCE=120     # Wall and uptime elapsed may differ by two minutes
MAX_CONTIGUOUS_SECONDS=21600  # Reject an uninterrupted segment over six hours
MAX_SESSION_SECONDS=86400     # Reject a complete launch over 24 hours
LOCK_RETRIES=6                # Initial attempt plus five POSIX one second waits
STALE_LOCK_SECONDS=30

TMP_FILE=""
LOCK_HELD=0

LOG_FILE() {
	LEVEL=$1
	shift
	MESSAGE=$*

	case "$LEVEL" in
		ERROR) LOG_ERROR "$0" 0 "$TRACK_TAG" "$MESSAGE" ;;
		WARN)  LOG_WARN  "$0" 0 "$TRACK_TAG" "$MESSAGE" ;;
		DEBUG) LOG_DEBUG "$0" 0 "$TRACK_TAG" "$MESSAGE" ;;
		*)     LOG_INFO  "$0" 0 "$TRACK_TAG" "$MESSAGE" ;;
	esac

	mkdir -p "$TRACK_LOG_DIR" 2>/dev/null || :
	printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" "$LEVEL" "$MESSAGE" >>"$TRACK_LOG" 2>/dev/null || :
}

CLEANUP() {
	[ -n "$TMP_FILE" ] && rm -f "$TMP_FILE" 2>/dev/null
	if [ "$LOCK_HELD" -eq 1 ]; then
		rm -f "$LOCK_DIR/pid" "$LOCK_DIR/time" 2>/dev/null
		rmdir "$LOCK_DIR" 2>/dev/null
	fi
}

trap 'CLEANUP' 0 HUP INT TERM

IS_UINT() {
	case ${1-} in
		''|*[!0-9]*) return 1 ;;
		*) return 0 ;;
	esac
}

GET_UPTIME() {
	if [ -r /proc/uptime ]; then
		IFS=' ' read -r UPTIME_VALUE UPTIME_REST </proc/uptime
		UPTIME_VALUE=${UPTIME_VALUE%%.*}
		IS_UINT "$UPTIME_VALUE" && {
			printf '%s\n' "$UPTIME_VALUE"
			return 0
		}
	fi
	printf '0\n'
}

GET_BOOT_ID() {
	if [ -r /proc/sys/kernel/random/boot_id ]; then
		IFS= read -r BOOT_VALUE </proc/sys/kernel/random/boot_id
		[ -n "$BOOT_VALUE" ] && {
			printf '%s\n' "$BOOT_VALUE"
			return 0
		}
	fi
	printf 'unknown\n'
}

CLOCK_IN_RANGE() {
	IS_UINT "$1" || return 1
	[ "$1" -ge "$TIME_FLOOR" ] && [ "$1" -le "$TIME_CEILING" ]
}

READ_HIGHWATER() {
	HW_WALL=0
	HW_UPTIME=0
	HW_BOOT=""

	[ -r "$HIGHWATER_FILE" ] || return 0
	IFS=' ' read -r HW_WALL HW_UPTIME HW_BOOT <"$HIGHWATER_FILE"
	IS_UINT "$HW_WALL" || HW_WALL=0
	IS_UINT "$HW_UPTIME" || HW_UPTIME=0
}

IS_CURRENT_CLOCK_SANE() {
	CLOCK_IN_RANGE "$NOW" || return 1
	READ_HIGHWATER

	# A known clock must not move backwards!
	if [ "$HW_WALL" -gt 0 ] && [ "$NOW" -lt $((HW_WALL - TIME_BACKWARD_GRACE)) ]; then
		return 1
	fi

	if [ -n "$HW_BOOT" ] && [ "$HW_BOOT" = "$BOOT_ID" ] && \
	   [ "$HW_WALL" -gt 0 ] && [ "$HW_UPTIME" -gt 0 ] && \
	   [ "$UPTIME_NOW" -ge "$HW_UPTIME" ]; then
		HW_WALL_DELTA=$((NOW - HW_WALL))
		HW_UPTIME_DELTA=$((UPTIME_NOW - HW_UPTIME))
		HW_DIFF=$((HW_WALL_DELTA - HW_UPTIME_DELTA))
		[ "$HW_DIFF" -lt 0 ] && HW_DIFF=$((-HW_DIFF))
		[ "$HW_DIFF" -le "$CLOCK_DELTA_TOLERANCE" ] || return 1
	fi

	return 0
}

UPDATE_HIGHWATER() {
	READ_HIGHWATER
	[ "$NOW" -le "$HW_WALL" ] && return 0
	TMP_FILE="$HIGHWATER_FILE.tmp.$$"
	if printf '%s %s %s\n' "$NOW" "$UPTIME_NOW" "$BOOT_ID" >"$TMP_FILE" && mv -f "$TMP_FILE" "$HIGHWATER_FILE"; then
		TMP_FILE=""
		return 0
	fi
	LOG_FILE WARN "Unable to update clock high-water file"
	return 1
}

WRITE_CURRENT() {
	TMP_FILE="$CURRENT_FILE.tmp.$$"
	if printf '%s\n%s\n%s\n' "$NAME" "$CORE" "$FILE" >"$TMP_FILE" && mv -f "$TMP_FILE" "$CURRENT_FILE"; then
		TMP_FILE=""
		return 0
	fi

	rm -f "$TMP_FILE" 2>/dev/null
	TMP_FILE=""
	LOG_FILE WARN "Unable to record the current tracking session"
	return 1
}

CLEAR_CURRENT() {
	rm -f "$CURRENT_FILE" 2>/dev/null || :
}

ACQUIRE_LOCK() {
	LOCK_TRY=0
	while ! mkdir "$LOCK_DIR" 2>/dev/null; do
		LOCK_TRY=$((LOCK_TRY + 1))

		# Recover a lock left by a killed process when the timestamps old
		if [ -r "$LOCK_DIR/time" ]; then
			IFS= read -r LOCK_TIME <"$LOCK_DIR/time"
			if IS_UINT "$LOCK_TIME" && CLOCK_IN_RANGE "$NOW" && [ "$NOW" -ge "$LOCK_TIME" ] && \
			   [ $((NOW - LOCK_TIME)) -gt "$STALE_LOCK_SECONDS" ]; then
				rm -f "$LOCK_DIR/pid" "$LOCK_DIR/time" 2>/dev/null
				rmdir "$LOCK_DIR" 2>/dev/null || :
				continue
			fi
		fi

		[ "$LOCK_TRY" -lt "$LOCK_RETRIES" ] || {
			LOG_FILE ERROR "Timed out waiting for activity tracker lock"
			return 1
		}
		sleep 1
	done

	LOCK_HELD=1
	printf '%s\n' "$$" >"$LOCK_DIR/pid" 2>/dev/null || :
	printf '%s\n' "$NOW" >"$LOCK_DIR/time" 2>/dev/null || :
	return 0
}

ATOMIC_JQ() {
	FILTER=$1
	shift
	TMP_FILE="$TRACK_JSON.tmp.$$"

	if jq "$@" "$FILTER" "$TRACK_JSON" >"$TMP_FILE" 2>/dev/null && \
	   [ -s "$TMP_FILE" ] && jq empty "$TMP_FILE" 2>/dev/null; then
		if mv -f "$TMP_FILE" "$TRACK_JSON"; then
			TMP_FILE=""
			return 0
		fi
	fi

	rm -f "$TMP_FILE" 2>/dev/null
	TMP_FILE=""
	LOG_FILE ERROR "Atomic JSON update failed for action '$ACTION' and file '$FILE'"
	return 1
}

INITIALISE_DATA() {
	mkdir -p "$TRACK_DIR" "$TRACK_LOG_DIR" 2>/dev/null || {
		LOG_FILE ERROR "Unable to create activity tracker directories"
		return 1
	}

	if [ ! -s "$TRACK_JSON" ]; then
		TMP_FILE="$TRACK_JSON.tmp.$$"
		printf '{}\n' >"$TMP_FILE" && mv -f "$TMP_FILE" "$TRACK_JSON" || return 1
		TMP_FILE=""
	fi

	if ! jq empty "$TRACK_JSON" 2>/dev/null; then
		CORRUPT="$TRACK_JSON.corrupt.$NOW"
		cp -f "$TRACK_JSON" "$CORRUPT" 2>/dev/null || :
		TMP_FILE="$TRACK_JSON.tmp.$$"
		printf '{}\n' >"$TMP_FILE" && mv -f "$TMP_FILE" "$TRACK_JSON" || return 1
		TMP_FILE=""
		LOG_FILE ERROR "Invalid playtime JSON preserved as '$CORRUPT'; tracker database reset"
	fi

	return 0
}

MIGRATE_JSON() {
	[ -e "$MIGRATION_MARKER" ] && return 0
	grep -q '"/mnt/union/' "$TRACK_JSON" 2>/dev/null || {
		: >"$MIGRATION_MARKER"
		return 0
	}

	# Resolve legacy union paths once. Each mutation remains atomic.
	jq -r 'keys[] | select(startswith("/mnt/union/"))' "$TRACK_JSON" 2>/dev/null |
	while IFS= read -r OLD_PATH; do
		RELATIVE=${OLD_PATH#/mnt/union/}
		NEW_PATH=""
		for MOUNT in /mnt/usb /mnt/sdcard /mnt/mmc; do
			CANDIDATE=$MOUNT/$RELATIVE
			if [ -f "$CANDIDATE" ] || [ -d "$CANDIDATE" ]; then
				NEW_PATH=$CANDIDATE
				break
			fi
		done

		if [ -n "$NEW_PATH" ]; then
			ATOMIC_JQ '
				if has($old) then
					if has($new) then del(.[$old])
					else .[$new] = .[$old] | del(.[$old]) end
				else . end
			' --arg old "$OLD_PATH" --arg new "$NEW_PATH" || exit 1
		else
			ATOMIC_JQ 'del(.[$old])' --arg old "$OLD_PATH" || exit 1
		fi
	done || return 1

	: >"$MIGRATION_MARKER"
}

VALIDATE_SEGMENT() {
	SEGMENT_WALL_START=$1
	SEGMENT_UPTIME_START=$2
	SEGMENT_BOOT_START=$3

	SEGMENT_SECONDS=0
	CLOCK_IN_RANGE "$SEGMENT_WALL_START" || return 1
	[ "$NOW_VALID" -eq 1 ] || return 1
	[ "$NOW" -ge "$SEGMENT_WALL_START" ] || return 1

	WALL_ELAPSED=$((NOW - SEGMENT_WALL_START))
	[ "$WALL_ELAPSED" -le "$MAX_CONTIGUOUS_SECONDS" ] || return 1

	if IS_UINT "$SEGMENT_UPTIME_START" && [ "$SEGMENT_UPTIME_START" -gt 0 ] && \
	   [ "$UPTIME_NOW" -gt 0 ] && [ "$SEGMENT_BOOT_START" = "$BOOT_ID" ]; then
		[ "$UPTIME_NOW" -ge "$SEGMENT_UPTIME_START" ] || return 1
		UPTIME_ELAPSED=$((UPTIME_NOW - SEGMENT_UPTIME_START))
		DELTA_DIFF=$((WALL_ELAPSED - UPTIME_ELAPSED))
		[ "$DELTA_DIFF" -lt 0 ] && DELTA_DIFF=$((-DELTA_DIFF))
		[ "$DELTA_DIFF" -le "$CLOCK_DELTA_TOLERANCE" ] || return 1
	fi

	SEGMENT_SECONDS=$WALL_ELAPSED
	return 0
}

START_TRACKING() {
	if [ "$NOW_VALID" -eq 1 ]; then
		START_WALL=$NOW
		START_UPTIME=$UPTIME_NOW
		START_BOOT=$BOOT_ID
		SESSION_STATE=active
	else
		START_WALL=0
		START_UPTIME=0
		START_BOOT=""
		SESSION_STATE=invalid_clock
	fi

	ATOMIC_JQ '
		.[$path] = ((.[$path] // {}) + {
			name: $name,
			last_core: $core,
			last_device: $device,
			last_mode: $mode,
			launches: ((.[$path].launches // 0) + 1),
			core_launches: (.[$path].core_launches // {}),
			device_launches: (.[$path].device_launches // {}),
			mode_launches: (.[$path].mode_launches // {}),
			total_time: ((.[$path].total_time // 0) + (
				if (.[$path].session_state // "stopped") == "stopped"
				then 0
				else (.[$path].session_accumulated // 0) end
			)),
			avg_time: (.[$path].avg_time // 0),
			last_session: (.[$path].last_session // 0),
			start_time: $wall,
			start_uptime: $uptime,
			start_boot_id: $boot,
			session_id: $session_id,
			session_state: $state,
			session_accumulated: 0
		})
		| .[$path].core_launches[$core] = ((.[$path].core_launches[$core] // 0) + 1)
		| .[$path].device_launches[$device] = ((.[$path].device_launches[$device] // 0) + 1)
		| .[$path].mode_launches[$mode] = ((.[$path].mode_launches[$mode] // 0) + 1)
	' \
		--arg path "$FILE" --arg name "$NAME" --arg core "$CORE" \
		--arg device "$BOARD_NAME" --arg mode "$MODE" \
		--argjson wall "$START_WALL" --argjson uptime "$START_UPTIME" \
		--arg boot "$START_BOOT" --arg session_id "$SESSION_ID" --arg state "$SESSION_STATE" || return 1

	WRITE_CURRENT
}

SUSPEND_TRACKING() {
	ENTRY=$(jq -r --arg path "$FILE" '
		if .[$path] then
			[.[$path].start_time // 0, .[$path].start_uptime // 0,
			 ((.[$path].start_boot_id // "-") | if . == "" then "-" else . end), .[$path].session_accumulated // 0,
			 .[$path].session_state // ""] | @tsv
		else empty end
	' "$TRACK_JSON" 2>/dev/null)

	[ -n "$ENTRY" ] || {
		LOG_FILE WARN "No tracker entry found on suspend for '$FILE'"
		return 0
	}

	OLD_IFS=$IFS
	IFS="$(printf '\t')"

	set -- $ENTRY
	IFS=$OLD_IFS

	START_WALL=${1-0}
	START_UPTIME=${2-0}
	START_BOOT=${3-}

	ACCUMULATED=${4-0}
	STATE=${5-}
	IS_UINT "$ACCUMULATED" || ACCUMULATED=0

	SEGMENT_SECONDS=0
	if [ "$STATE" = active ] && VALIDATE_SEGMENT "$START_WALL" "$START_UPTIME" "$START_BOOT"; then
		NEW_ACCUMULATED=$((ACCUMULATED + SEGMENT_SECONDS))
		if [ "$NEW_ACCUMULATED" -gt "$MAX_SESSION_SECONDS" ]; then
			NEW_ACCUMULATED=$ACCUMULATED
			LOG_FILE WARN "Discarded suspend segment for '$NAME': complete session would exceed policy"
		fi
	else
		NEW_ACCUMULATED=$ACCUMULATED
		[ "$STATE" = active ] && LOG_FILE WARN "Discarded unsafe pre-suspend timing segment for '$NAME'"
	fi

	ATOMIC_JQ '
		if .[$path] then
			.[$path].session_accumulated = $accumulated
			| .[$path].session_state = "suspended"
			| .[$path].start_time = 0
			| .[$path].start_uptime = 0
			| .[$path].start_boot_id = ""
		else . end
	' --arg path "$FILE" --argjson accumulated "$NEW_ACCUMULATED"
}

RESUME_TRACKING() {
	if ! jq -e --arg path "$FILE" '.[$path] != null' "$TRACK_JSON" >/dev/null 2>&1; then
		LOG_FILE WARN "No tracker entry found on resume for '$FILE'"
		return 0
	fi

	PREVIOUS_STATE=$(jq -r --arg path "$FILE" '.[$path].session_state // ""' "$TRACK_JSON" 2>/dev/null)
	if [ "$PREVIOUS_STATE" != suspended ]; then
		LOG_FILE WARN "Resume without a matching suspend for '$NAME'; discarded the ambiguous elapsed interval"
	fi

	if [ "$NOW_VALID" -eq 1 ]; then
		ATOMIC_JQ '
			.[$path].start_time = $wall
			| .[$path].start_uptime = $uptime
			| .[$path].start_boot_id = $boot
			| .[$path].session_state = "active"
		' --arg path "$FILE" --argjson wall "$NOW" --argjson uptime "$UPTIME_NOW" --arg boot "$BOOT_ID"
	else
		ATOMIC_JQ '
			.[$path].start_time = 0
			| .[$path].start_uptime = 0
			| .[$path].start_boot_id = ""
			| .[$path].session_state = "invalid_clock"
		' --arg path "$FILE"
		LOG_FILE WARN "Resume timing disabled for '$NAME' because the system clock is invalid"
	fi
}

STOP_TRACKING() {
	ENTRY=$(jq -r --arg path "$FILE" '
		if .[$path] then
			[.[$path].start_time // 0, .[$path].start_uptime // 0,
			 ((.[$path].start_boot_id // "-") | if . == "" then "-" else . end), .[$path].session_accumulated // 0,
			 .[$path].session_state // ""] | @tsv
		else empty end
	' "$TRACK_JSON" 2>/dev/null)

	[ -n "$ENTRY" ] || {
		LOG_FILE WARN "No tracker entry found on stop for '$FILE'"
		return 0
	}

	OLD_IFS=$IFS
	IFS="$(printf '\t')"
	set -- $ENTRY
	IFS=$OLD_IFS
	START_WALL=${1-0}
	START_UPTIME=${2-0}
	START_BOOT=${3-}
	ACCUMULATED=${4-0}
	STATE=${5-}
	IS_UINT "$ACCUMULATED" || ACCUMULATED=0

	SEGMENT_SECONDS=0
	if [ "$STATE" = active ]; then
		if VALIDATE_SEGMENT "$START_WALL" "$START_UPTIME" "$START_BOOT"; then
			SESSION_SECONDS=$((ACCUMULATED + SEGMENT_SECONDS))
		else
			SESSION_SECONDS=$ACCUMULATED
			LOG_FILE WARN "Discarded unsafe final timing segment for '$NAME'"
		fi
	else
		SESSION_SECONDS=$ACCUMULATED
	fi

	if [ "$SESSION_SECONDS" -gt "$MAX_SESSION_SECONDS" ]; then
		LOG_FILE WARN "Rejected complete session for '$NAME' because it exceeded $MAX_SESSION_SECONDS seconds"
		SESSION_SECONDS=0
	fi

	ATOMIC_JQ '
		.[$path].last_session = $session
		| .[$path].total_time = ((.[$path].total_time // 0) + $session)
		| .[$path].avg_time = (
			if (.[$path].launches // 0) > 0
			then .[$path].total_time / .[$path].launches
			else 0 end
		)
		| .[$path].start_time = 0
		| .[$path].start_uptime = 0
		| .[$path].start_boot_id = ""
		| .[$path].session_id = ""
		| .[$path].session_state = "stopped"
		| .[$path].session_accumulated = 0
	' --arg path "$FILE" --argjson session "$SESSION_SECONDS" && \
	LOG_FILE DEBUG "Accepted session time for '$NAME': $SESSION_SECONDS seconds"

	CLEAR_CURRENT
}

case "$ACTION" in
	start|suspend|resume|stop) ;;
	*)
		printf 'Usage: %s <name> <core> <file> <start|suspend|resume|stop>\n' "$0" >&2
		exit 1
		;;
esac

[ -n "$FILE" ] || {
	printf 'Error: file path must not be empty\n' >&2
	exit 1
}

command -v jq >/dev/null 2>&1 || {
	LOG_FILE ERROR "jq is required for activity tracking"
	exit 1
}

if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
	MODE=console
else
	MODE=handheld
fi

BOARD_NAME=$(GET_VAR "device" "board/name")
NOW=$(date +%s 2>/dev/null)
IS_UINT "$NOW" || NOW=0
UPTIME_NOW=$(GET_UPTIME)
BOOT_ID=$(GET_BOOT_ID)
SESSION_ID="$BOOT_ID-$$-$NOW"

NOW_VALID=1
if ! IS_CURRENT_CLOCK_SANE; then
	NOW_VALID=0
	LOG_FILE WARN "System clock is unsafe (epoch $NOW); this call will not contribute untrusted elapsed time"
fi

ACQUIRE_LOCK || exit 1
INITIALISE_DATA || exit 1
MIGRATE_JSON || LOG_FILE WARN "Legacy union-path migration was incomplete"
[ "$NOW_VALID" -eq 1 ] && UPDATE_HIGHWATER

LOG_FILE INFO "Activity tracker '$ACTION' for '$NAME' (core: $CORE)"

case "$ACTION" in
	start)   START_TRACKING ;;
	suspend) SUSPEND_TRACKING ;;
	resume)  RESUME_TRACKING ;;
	stop)    STOP_TRACKING ;;
esac
