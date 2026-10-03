#!/bin/sh

# The jq filters keep their single quotes on purpose, the dollar names in them
# belong to jq and are bound with `--arg` so any shell must leave britney alone!
# shellcheck disable=SC2016

. /opt/muos/script/var/func.sh

if [ "$#" -eq 1 ] && [ "$1" = migrate ]; then
	NAME=""
	CORE=""
	FILE=""
	ACTION=migrate
else
	NAME=${1-}
	CORE=${2-}
	FILE=${3-}
	ACTION=${4-}
fi

[ "$ACTION" = migrate ] || [ "$(GET_VAR "config" "settings/advanced/activity")" != 0 ] || exit 0

TRACK_TAG="TRACK"
TRACK_DIR="$MUOS_STORE_DIR/info/track"
LEGACY_JSON="$TRACK_DIR/playtime_data.json"
TRACK_LOG="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/playtime_error.log"
TRACK_LOG_DIR=${TRACK_LOG%/*}
LOCK_DIR="$TRACK_DIR/.playtime.lock"
HIGHWATER_FILE="$TRACK_DIR/.time_highwater"
CURRENT_FILE="$TRACK_DIR/.current_session"
HISTORY_DIR="$MUOS_STORE_DIR/info/history"
WASABI_HISTORY="$MUOS_STORE_DIR/save/wasabi/history.tsv"
CONTENT_INFO_DIR="$MUOS_SHARE_DIR/info/content"
RUNTIME_MARKER="$TRACK_DIR/.runtime_backfill_v1"
BATTERY_DIR="$MUOS_RUN_DIR/battery"
RECORD_VERSION=1
SESSION_LIMIT=50
TAB=$(printf '\t')

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

	case "$LEVEL" in
		ERROR | WARN)
			mkdir -p "$TRACK_LOG_DIR" 2>/dev/null || :
			printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" "$LEVEL" "$MESSAGE" >>"$TRACK_LOG" 2>/dev/null || :
			;;
	esac
}

CLEANUP() {
	[ -n "$TMP_FILE" ] && rm -f "$TMP_FILE" 2>/dev/null
	if [ "$LOCK_HELD" -eq 1 ]; then
		rm -f "$LOCK_DIR/pid" "$LOCK_DIR/time" "$LOCK_DIR/boot" 2>/dev/null
		rmdir "$LOCK_DIR" 2>/dev/null
	fi
}

trap 'CLEANUP' 0 HUP INT TERM

IS_UINT() {
	case ${1-} in
		'' | *[!0-9]*) return 1 ;;
		*) return 0 ;;
	esac
}

GET_UPTIME() {
	if [ -r /proc/uptime ]; then
		IFS=' ' read -r UPTIME_VALUE _ </proc/uptime
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

READ_NUMBER() {
	RN_VALUE=
	[ -r "$1" ] && IFS= read -r RN_VALUE <"$1"
	if IS_UINT "$RN_VALUE"; then
		printf '%s' "$RN_VALUE"
	else
		printf 'null'
	fi
}

READ_GOVERNOR() {
	RG_FILE=$(GET_VAR "device" "cpu/governor")
	[ -n "$RG_FILE" ] || RG_FILE=/sys/devices/system/cpu/cpufreq/policy0/scaling_governor
	RG_VALUE=
	[ -r "$RG_FILE" ] && IFS= read -r RG_VALUE <"$RG_FILE"
	printf '%s' "$RG_VALUE"
}

SAMPLE_TEMPERATURE() {
	READ_NUMBER /sys/class/thermal/thermal_zone0/temp
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

ACQUIRE_LOCK() {
	LOCK_TRY=0
	while ! mkdir "$LOCK_DIR" 2>/dev/null; do
		LOCK_TRY=$((LOCK_TRY + 1))

		LOCK_BOOT=
		LOCK_TIME=
		[ -r "$LOCK_DIR/boot" ] && IFS= read -r LOCK_BOOT <"$LOCK_DIR/boot"
		[ -r "$LOCK_DIR/time" ] && IFS= read -r LOCK_TIME <"$LOCK_DIR/time"

		# Recover a lock left by an earlier boot, or by a killed process once its uptime stamp is old
		if { [ -n "$LOCK_BOOT" ] && [ "$LOCK_BOOT" != "$BOOT_ID" ]; } || \
		   { IS_UINT "$LOCK_TIME" && [ "$UPTIME_NOW" -ge "$LOCK_TIME" ] && \
		     [ $((UPTIME_NOW - LOCK_TIME)) -gt "$STALE_LOCK_SECONDS" ]; }; then
			rm -f "$LOCK_DIR/pid" "$LOCK_DIR/time" "$LOCK_DIR/boot" 2>/dev/null
			rmdir "$LOCK_DIR" 2>/dev/null || :
			continue
		fi

		[ "$LOCK_TRY" -lt "$LOCK_RETRIES" ] || {
			LOG_FILE ERROR "Timed out waiting for activity tracker lock"
			return 1
		}
		sleep 1
	done

	LOCK_HELD=1
	printf '%s\n' "$$" >"$LOCK_DIR/pid" 2>/dev/null || :
	printf '%s\n' "$UPTIME_NOW" >"$LOCK_DIR/time" 2>/dev/null || :
	printf '%s\n' "$BOOT_ID" >"$LOCK_DIR/boot" 2>/dev/null || :
	return 0
}

CONTENT_KEY() {
	CK_PATH=$1
	case "$CK_PATH" in
		*/ROMS/*) CK_PATH=${CK_PATH#*/ROMS/} ;;
	esac
	printf '%s' "$CK_PATH" | tr '[:upper:]' '[:lower:]'
}

FNV1A() {
	FH=2166136261
	for FB in $(printf '%s' "$1" | od -An -v -tu1); do
		FH=$((((FH ^ FB) * 16777619) & 4294967295))
	done
	printf '%08X' "$FH"
}

RECORD_PATH() {
	printf '%s/%s.json' "$TRACK_DIR" "$(FNV1A "$(CONTENT_KEY "$1")")"
}

WRITE_ATOMIC() {
	TMP_FILE="$1.tmp.$$"
	if printf '%s\n' "$2" >"$TMP_FILE" && mv -f "$TMP_FILE" "$1"; then
		TMP_FILE=""
		return 0
	fi
	rm -f "$TMP_FILE" 2>/dev/null
	TMP_FILE=""
	return 1
}

ATOMIC_RECORD() {
	AR_RECORD=$1
	AR_FILTER=$2
	shift 2
	TMP_FILE="$AR_RECORD.tmp.$$"

	if jq "$@" "$AR_FILTER" "$AR_RECORD" >"$TMP_FILE" 2>/dev/null && \
	   [ -s "$TMP_FILE" ] && jq empty "$TMP_FILE" 2>/dev/null; then
		if mv -f "$TMP_FILE" "$AR_RECORD"; then
			TMP_FILE=""
			return 0
		fi
	fi

	rm -f "$TMP_FILE" 2>/dev/null
	TMP_FILE=""
	LOG_FILE ERROR "Atomic record update failed for action '$ACTION' and record '$AR_RECORD'"
	return 1
}

ENSURE_RECORD() {
	ER_RECORD=$1

	if [ -s "$ER_RECORD" ]; then
		jq empty "$ER_RECORD" 2>/dev/null && return 0
		mv -f "$ER_RECORD" "$ER_RECORD.corrupt.$UPTIME_NOW" 2>/dev/null || :
		LOG_FILE ERROR "Invalid tracker record preserved as '$ER_RECORD.corrupt.$UPTIME_NOW'"
	fi

	WRITE_ATOMIC "$ER_RECORD" "$(jq -n -c \
		--argjson version "$RECORD_VERSION" \
		--arg key "$(CONTENT_KEY "$2")" \
		--arg path "$2" \
		'{
			"version": $version, "key": $key, "path": $path, "name": "", "system": "",
			"launches": 0, "total_time": 0, "first_played": 0, "last_played": 0,
			"last_session": 0, "longest_session": 0, "last_core": "", "last_device": "", "last_mode": "",
			"last_runtime": "", "cores": {}, "devices": {}, "modes": {}, "runtimes": {}, "endings": {},
			"sessions": [], "active": null
		}')"
}

WRITE_CURRENT() {
	TMP_FILE="$CURRENT_FILE.tmp.$$"
	if printf '%s\n%s\n%s\n%s\n' "$NAME" "$CORE" "$FILE" "$1" >"$TMP_FILE" && mv -f "$TMP_FILE" "$CURRENT_FILE"; then
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

SEGMENT() {
	SEGMENT_SECONDS=0
	SG_WALL=$1
	SG_UPTIME=$2
	SG_BOOT=$3

	case "$SG_BOOT" in
		'' | - | "$BOOT_ID") ;;
		*) return 1 ;;
	esac

	if IS_UINT "$SG_UPTIME" && [ "$SG_UPTIME" -gt 0 ] && [ "$UPTIME_NOW" -ge "$SG_UPTIME" ] && \
	   [ "$SG_BOOT" = "$BOOT_ID" ]; then
		SEGMENT_SECONDS=$((UPTIME_NOW - SG_UPTIME))
	elif [ "$NOW_VALID" -eq 1 ] && CLOCK_IN_RANGE "$SG_WALL" && [ "$NOW" -ge "$SG_WALL" ]; then
		SEGMENT_SECONDS=$((NOW - SG_WALL))
	else
		return 1
	fi

	[ "$SEGMENT_SECONDS" -le "$MAX_CONTIGUOUS_SECONDS" ] && return 0
	SEGMENT_SECONDS=0
	return 1
}

READ_ACTIVE() {
	[ -s "$1" ] || return 1

	ACTIVE=$(jq -r '
		if .active then
			[.active.state // "", .active.start_time // 0, .active.start_uptime // 0,
			 ((.active.start_boot_id // "-") | if . == "" then "-" else . end), .active.accumulated // 0] | @tsv
		else empty end
	' "$1" 2>/dev/null)

	[ -n "$ACTIVE" ] || return 1

	OLD_IFS=$IFS
	IFS=$TAB
	# shellcheck disable=SC2086
	set -- $ACTIVE
	IFS=$OLD_IFS
	ACTIVE_STATE=${1-}
	ACTIVE_WALL=${2-0}
	ACTIVE_UPTIME=${3-0}
	ACTIVE_BOOT=${4-}
	ACTIVE_ACCUMULATED=${5-0}
	IS_UINT "$ACTIVE_ACCUMULATED" || ACTIVE_ACCUMULATED=0
	return 0
}

FINALISE() {
	FN_RECORD=$1
	FN_ENDED=$2
	FN_EXIT=${3-}

	READ_ACTIVE "$FN_RECORD" || return 0

	FN_SECONDS=$ACTIVE_ACCUMULATED
	if [ "$ACTIVE_STATE" = active ]; then
		if SEGMENT "$ACTIVE_WALL" "$ACTIVE_UPTIME" "$ACTIVE_BOOT"; then
			FN_SECONDS=$((FN_SECONDS + SEGMENT_SECONDS))
		else
			LOG_FILE WARN "Discarded unsafe final timing segment for '$FN_RECORD'"
		fi
	fi

	if [ "$FN_SECONDS" -gt "$MAX_SESSION_SECONDS" ]; then
		LOG_FILE WARN "Rejected complete session for '$FN_RECORD' because it exceeded $MAX_SESSION_SECONDS seconds"
		FN_SECONDS=0
	fi

	ATOMIC_RECORD "$FN_RECORD" '
		.active as $a
		| (if $a.capacity != null and $capacity != null and ($a.charging // 1) == 0 and ($charging // 1) == 0
		   then ([$a.capacity - $capacity, 0] | max) else null end) as $battery
		| (if ($a.temperature_count // 0) > 0
		   then (($a.temperature_sum / $a.temperature_count / 100) | floor) / 10 else null end) as $temperature
		| .total_time = (.total_time // 0) + $seconds
		| .last_session = $seconds
		| .longest_session = ([.longest_session // 0, $seconds] | max)
		| .cores[$a.core // ""].time = ((.cores[$a.core // ""].time // 0) + $seconds)
		| .devices[$a.device // ""].time = ((.devices[$a.device // ""].time // 0) + $seconds)
		| .modes[$a.mode // ""].time = ((.modes[$a.mode // ""].time // 0) + $seconds)
		| if ($a.runtime // "") != "" then .runtimes[$a.runtime].time = ((.runtimes[$a.runtime].time // 0) + $seconds) else . end
		| .endings[$ended] = ((.endings[$ended] // 0) + 1)
		| .sessions = ((.sessions // []) + [{
			"start": ($a.started // 0), "length": $seconds, "core": ($a.core // ""), "runtime": ($a.runtime // ""),
			"device": ($a.device // ""), "mode": ($a.mode // ""), "battery": $battery,
			"temperature": $temperature, "governor": ($a.governor // ""),
			"suspends": ($a.suspends // 0), "ended": $ended, "exit": $exit
		  }])[-$limit:]
		| .active = null
	' --argjson seconds "$FN_SECONDS" --arg ended "$FN_ENDED" \
		--argjson exit "${FN_EXIT:-null}" --argjson limit "$SESSION_LIMIT" \
		--argjson capacity "$(READ_NUMBER "$BATTERY_DIR/capacity")" \
		--argjson charging "$(READ_NUMBER "$BATTERY_DIR/charging")" && \
	LOG_FILE DEBUG "Accepted session time for '$FN_RECORD': $FN_SECONDS seconds ($FN_ENDED)"
}

CLOSE_ORPHAN() {
	[ -r "$CURRENT_FILE" ] || return 0

	CO_FILE=
	CO_HASH=
	{
		read -r _
		read -r _
		read -r CO_FILE
		read -r CO_HASH
	} <"$CURRENT_FILE"

	if [ -n "$CO_HASH" ]; then
		CO_RECORD="$TRACK_DIR/$CO_HASH"
	elif [ -n "$CO_FILE" ]; then
		CO_RECORD=$(RECORD_PATH "$CO_FILE")
	else
		return 0
	fi

	READ_ACTIVE "$CO_RECORD" || return 0
	if [ "$ACTIVE_BOOT" != "$BOOT_ID" ] && [ "$ACTIVE_STATE" = active ]; then
		FINALISE "$CO_RECORD" lost
	else
		FINALISE "$CO_RECORD" interrupted
	fi
}

START_TRACKING() {
	CLOSE_ORPHAN

	ST_RECORD=$(RECORD_PATH "$FILE")
	ENSURE_RECORD "$ST_RECORD" "$FILE" || return 1

	ST_WALL=0
	if [ "$NOW_VALID" -eq 1 ]; then
		ST_WALL=$NOW
	else
		LOG_FILE WARN "System clock is unsafe for '$NAME'; session time uses uptime and no date is recorded"
	fi

	ATOMIC_RECORD "$ST_RECORD" '
		.version = $version
		| .key = $key
		| .path = $path
		| .name = $name
		| .system = (if $system == "" then (.system // "") else $system end)
		| .launches = (.launches // 0) + 1
		| .first_played = (if (.first_played // 0) > 0 then .first_played else $wall end)
		| .last_played = (if $wall > 0 then $wall else (.last_played // 0) end)
		| .last_core = $core
		| .last_device = $device
		| .last_mode = $mode
		| .last_runtime = $runtime
		| .runtimes[$runtime].launches = ((.runtimes[$runtime].launches // 0) + 1)
		| .cores[$core].launches = ((.cores[$core].launches // 0) + 1)
		| .devices[$device].launches = ((.devices[$device].launches // 0) + 1)
		| .modes[$mode].launches = ((.modes[$mode].launches // 0) + 1)
		| .active = {
			"id": $session_id, "state": "active", "started": $wall, "start_time": $wall,
			"start_uptime": $uptime, "start_boot_id": $boot, "accumulated": 0,
			"capacity": $capacity, "charging": $charging, "governor": $governor, "suspends": 0,
			"temperature_sum": ($temperature // 0), "temperature_count": (if $temperature then 1 else 0 end),
			"core": $core, "device": $device, "mode": $mode, "runtime": $runtime
		}
	' \
		--argjson version "$RECORD_VERSION" --arg key "$(CONTENT_KEY "$FILE")" --arg path "$FILE" \
		--arg name "$NAME" --arg system "${TRACK_SYSTEM-}" --arg core "$CORE" \
		--arg device "$BOARD_NAME" --arg mode "$MODE" --arg runtime "$RUNTIME" --argjson wall "$ST_WALL" \
		--argjson uptime "$UPTIME_NOW" --arg boot "$BOOT_ID" --arg session_id "$SESSION_ID" \
		--arg governor "$(READ_GOVERNOR)" \
		--argjson capacity "$(READ_NUMBER "$BATTERY_DIR/capacity")" \
		--argjson charging "$(READ_NUMBER "$BATTERY_DIR/charging")" \
		--argjson temperature "$(SAMPLE_TEMPERATURE)" || return 1

	WRITE_CURRENT "${ST_RECORD##*/}"
}

SUSPEND_TRACKING() {
	SP_RECORD=$(RECORD_PATH "$FILE")

	READ_ACTIVE "$SP_RECORD" || {
		LOG_FILE WARN "No active session found on suspend for '$FILE'"
		return 0
	}

	SP_ACCUMULATED=$ACTIVE_ACCUMULATED
	if [ "$ACTIVE_STATE" = active ]; then
		if SEGMENT "$ACTIVE_WALL" "$ACTIVE_UPTIME" "$ACTIVE_BOOT"; then
			SP_ACCUMULATED=$((SP_ACCUMULATED + SEGMENT_SECONDS))
		else
			LOG_FILE WARN "Discarded unsafe pre-suspend timing segment for '$NAME'"
		fi
	fi

	if [ "$SP_ACCUMULATED" -gt "$MAX_SESSION_SECONDS" ]; then
		SP_ACCUMULATED=$ACTIVE_ACCUMULATED
		LOG_FILE WARN "Discarded suspend segment for '$NAME': complete session would exceed policy"
	fi

	ATOMIC_RECORD "$SP_RECORD" '
		.active.accumulated = $accumulated
		| .active.state = "suspended"
		| .active.start_time = 0
		| .active.start_uptime = 0
		| .active.start_boot_id = ""
		| .active.suspends = ((.active.suspends // 0) + 1)
		| if $temperature then
			.active.temperature_sum = ((.active.temperature_sum // 0) + $temperature)
			| .active.temperature_count = ((.active.temperature_count // 0) + 1)
		  else . end
	' --argjson accumulated "$SP_ACCUMULATED" --argjson temperature "$(SAMPLE_TEMPERATURE)"
}

RESUME_TRACKING() {
	RS_RECORD=$(RECORD_PATH "$FILE")

	READ_ACTIVE "$RS_RECORD" || {
		LOG_FILE WARN "No active session found on resume for '$FILE'"
		return 0
	}

	[ "$ACTIVE_STATE" = suspended ] || \
		LOG_FILE WARN "Resume without a matching suspend for '$NAME'; discarded the ambiguous elapsed interval"

	RS_WALL=0
	[ "$NOW_VALID" -eq 1 ] && RS_WALL=$NOW

	ATOMIC_RECORD "$RS_RECORD" '
		.active.start_time = $wall
		| .active.start_uptime = $uptime
		| .active.start_boot_id = $boot
		| .active.state = "active"
		| if $temperature then
			.active.temperature_sum = ((.active.temperature_sum // 0) + $temperature)
			| .active.temperature_count = ((.active.temperature_count // 0) + 1)
		  else . end
	' --argjson wall "$RS_WALL" --argjson uptime "$UPTIME_NOW" --arg boot "$BOOT_ID" \
		--argjson temperature "$(SAMPLE_TEMPERATURE)"
}

STOP_TRACKING() {
	SO_RECORD=$(RECORD_PATH "$FILE")

	if ! READ_ACTIVE "$SO_RECORD"; then
		LOG_FILE WARN "No active session found on stop for '$FILE'"
		CLEAR_CURRENT
		return 0
	fi

	SO_EXIT=${TRACK_EXIT-}
	IS_UINT "$SO_EXIT" || SO_EXIT=
	case "${TRACK_END-}:$SO_EXIT" in
		poweroff:*) SO_ENDED=poweroff ;;
		*:0 | *:) SO_ENDED=normal ;;
		*:64) SO_ENDED=switch ;;
		*) SO_ENDED=error ;;
	esac

	FINALISE "$SO_RECORD" "$SO_ENDED" "$SO_EXIT"
	CLEAR_CURRENT
}

RECOVERY_TIMES() {
	if [ -d "$HISTORY_DIR" ]; then
		for RT_FILE in "$HISTORY_DIR"/*.cfg; do
			[ -f "$RT_FILE" ] || continue
			IFS= read -r RT_PATH <"$RT_FILE" || continue
			RT_TIME=$(date -r "$RT_FILE" +%s 2>/dev/null)
			CLOCK_IN_RANGE "$RT_TIME" && printf '%s\t%s\n' "$RT_PATH" "$RT_TIME"
		done
	fi

	if [ -r "$WASABI_HISTORY" ]; then
		awk -F '\t' -v floor="$TIME_FLOOR" -v ceiling="$TIME_CEILING" \
			'$5 ~ /^[0-9]+$/ && $5 + 0 >= floor && $5 + 0 <= ceiling { print $1 "\t" $5 }' "$WASABI_HISTORY"
	fi
}

MIGRATE_LEGACY() {
	[ -e "$LEGACY_JSON" ] || return 0

	if ! jq empty "$LEGACY_JSON" 2>/dev/null; then
		mv -f "$LEGACY_JSON" "$LEGACY_JSON.corrupt" 2>/dev/null || :
		LOG_FILE ERROR "Invalid legacy playtime data preserved as '$LEGACY_JSON.corrupt' and not migrated"
		return 1
	fi

	MG_MAP="$TRACK_DIR/.migrate.map.$$"
	MG_SEEN="$TRACK_DIR/.migrate.seen.$$"
	MG_OUT="$TRACK_DIR/.migrate.out.$$"

	jq -r 'to_entries[] | select(.value | type == "object") | .key' "$LEGACY_JSON" 2>/dev/null |
		while IFS= read -r MG_PATH; do
			MG_KEY=$(CONTENT_KEY "$MG_PATH")
			printf '%s\t%s\t%s\n' "$MG_PATH" "$MG_KEY" "$(FNV1A "$MG_KEY")"
		done >"$MG_MAP"

	RECOVERY_TIMES >"$MG_SEEN" 2>/dev/null

	if ! jq -r --rawfile map "$MG_MAP" --rawfile seen "$MG_SEEN" --argjson version "$RECORD_VERSION" '
		def table($text): $text | split("\n") | map(select(length > 0) | split("\t"));
		def stamp: if type == "number" and . > 0 then floor else 0 end;
		def counts: if type == "object" then with_entries(.value = {"launches": (.value // 0), "time": 0}) else {} end;
		def addmaps($a; $b): reduce (($b // {}) | to_entries[]) as $e (($a // {});
			.[$e.key].launches = ((.[$e.key].launches // 0) + ($e.value.launches // 0))
			| .[$e.key].time = ((.[$e.key].time // 0) + ($e.value.time // 0)));
		(reduce table($map)[] as $row ({}; .[$row[0]] = {"key": $row[1], "hash": $row[2]})) as $m
		| (reduce table($seen)[] as $row ({}; .[$row[0]] = ([.[$row[0]] // 0, ($row[1] | tonumber? // 0)] | max))) as $r
		| [to_entries[] | select(.value | type == "object") | select($m[.key]) | .key as $path | .value as $v
			| [($v.last_played | stamp), ($v.start_time | stamp), ($r[$path] // 0)] as $times
			| {
				"hash": $m[$path].hash,
				"record": {
					"version": $version, "key": $m[$path].key, "path": $path,
					"name": ($v.name // ($path | split("/") | last)), "system": "",
					"launches": ($v.launches // 0), "total_time": ($v.total_time // 0),
					"first_played": ($times | map(select(. > 0)) | min // 0),
					"last_played": ($times | max),
					"last_session": ($v.last_session // 0), "longest_session": ($v.last_session // 0),
					"last_core": ($v.last_core // ""), "last_device": ($v.last_device // ""),
					"last_mode": ($v.last_mode // ""),
					"cores": ($v.core_launches | counts), "devices": ($v.device_launches | counts),
					"modes": ($v.mode_launches | counts), "endings": {}, "sessions": [], "active": null,
					"migrated": true
				}
			}]
		| group_by(.hash)[]
		| .[0].hash as $hash
		| (map(.record) | sort_by(.last_played)) as $list
		| (reduce $list[] as $item (($list | last) + {"launches": 0, "total_time": 0, "cores": {}, "devices": {}, "modes": {}};
			.launches += $item.launches
			| .total_time += $item.total_time
			| .longest_session = ([.longest_session, $item.longest_session] | max)
			| .cores = addmaps(.cores; $item.cores)
			| .devices = addmaps(.devices; $item.devices)
			| .modes = addmaps(.modes; $item.modes)))
		| .first_played = ($list | map(.first_played) | map(select(. > 0)) | min // 0)
		| $hash + "\t" + tojson
	' "$LEGACY_JSON" >"$MG_OUT" 2>/dev/null; then
		rm -f "$MG_MAP" "$MG_SEEN" "$MG_OUT"
		LOG_FILE ERROR "Legacy playtime migration failed; playtime_data.json was left in place"
		return 1
	fi

	MG_COUNT=0
	while IFS="$TAB" read -r MG_HASH MG_JSON; do
		[ -n "$MG_HASH" ] || continue
		MG_RECORD="$TRACK_DIR/$MG_HASH.json"

		if [ -s "$MG_RECORD" ] && jq empty "$MG_RECORD" 2>/dev/null; then
			MG_JSON=$(jq -c --argjson old "$MG_JSON" '
				def addmaps($a; $b): reduce (($b // {}) | to_entries[]) as $e (($a // {});
					.[$e.key].launches = ((.[$e.key].launches // 0) + ($e.value.launches // 0))
					| .[$e.key].time = ((.[$e.key].time // 0) + ($e.value.time // 0)));
				.launches = (.launches // 0) + $old.launches
				| .total_time = (.total_time // 0) + $old.total_time
				| .longest_session = ([.longest_session // 0, $old.longest_session] | max)
				| .first_played = ([.first_played // 0, $old.first_played] | map(select(. > 0)) | min // 0)
				| .last_played = ([.last_played // 0, $old.last_played] | max)
				| .cores = addmaps(.cores; $old.cores)
				| .devices = addmaps(.devices; $old.devices)
				| .modes = addmaps(.modes; $old.modes)
				| .migrated = true
			' "$MG_RECORD" 2>/dev/null) || continue
		fi

		WRITE_ATOMIC "$MG_RECORD" "$MG_JSON" && MG_COUNT=$((MG_COUNT + 1))
	done <"$MG_OUT"

	rm -f "$MG_MAP" "$MG_SEEN" "$MG_OUT"
	mv -f "$LEGACY_JSON" "$LEGACY_JSON.migrated" || return 1
	rm -f "$TRACK_DIR/.union_path_migration_v2" 2>/dev/null || :
	LOG_FILE INFO "Migrated legacy playtime data into $MG_COUNT tracker records"
}

READ_LINE() {
	RL_LINE=0
	RL_VALUE=
	while IFS= read -r RL_TEXT || [ -n "$RL_TEXT" ]; do
		RL_LINE=$((RL_LINE + 1))
		if [ "$RL_LINE" -eq "$2" ]; then
			RL_VALUE=$RL_TEXT
			break
		fi
	done <"$1"
	printf '%s' "$RL_VALUE"
}

ASSIGNED_RUNTIME() {
	AR_PATH=$1
	AR_CORE=$2

	case "$AR_PATH" in
		*/ROMS/*/*) AR_DIR=${AR_PATH#*/ROMS/} ;;
		*) AR_DIR= ;;
	esac

	AR_LAUNCH=
	if [ -n "$AR_DIR" ]; then
		AR_STEM=${AR_DIR##*/}
		AR_STEM=${AR_STEM%.*}
		AR_DIR=${AR_DIR%/*}
		[ -r "$CONTENT_INFO_DIR/$AR_DIR/$AR_STEM.cfg" ] && AR_LAUNCH=$(READ_LINE "$CONTENT_INFO_DIR/$AR_DIR/$AR_STEM.cfg" 6)
		[ -z "$AR_LAUNCH" ] && [ -r "$CONTENT_INFO_DIR/$AR_DIR/core.cfg" ] && AR_LAUNCH=$(READ_LINE "$CONTENT_INFO_DIR/$AR_DIR/core.cfg" 5)
	fi

	case "$AR_CORE:$AR_LAUNCH" in
		ext-video:*) printf 'wasabi' ;;
		*:mu-*) printf 'pickles' ;;
		ext-*:* | *:ext-*) printf 'external' ;;
		*) printf 'retroarch' ;;
	esac
}

BACKFILL_RUNTIME() {
	[ -e "$RUNTIME_MARKER" ] && return 0

	BF_COUNT=0
	for BF_RECORD in "$TRACK_DIR"/*.json; do
		[ -s "$BF_RECORD" ] || continue

		BF_FIELDS=$(jq -r 'select((.last_runtime // "") == "") | [.path // "", .last_core // ""] | @tsv' "$BF_RECORD" 2>/dev/null)
		[ -n "$BF_FIELDS" ] || continue

		BF_PATH=${BF_FIELDS%%"$TAB"*}
		BF_CORE=${BF_FIELDS#*"$TAB"}
		BF_RUNTIME=$(ASSIGNED_RUNTIME "$BF_PATH" "$BF_CORE")

		ATOMIC_RECORD "$BF_RECORD" '
			.last_runtime = $runtime
			| .runtimes = (if (.runtimes // {}) == {} then {($runtime): {"launches": (.launches // 0), "time": (.total_time // 0)}} else .runtimes end)
			| .sessions = ((.sessions // []) | map(if (.runtime // "") == "" then .runtime = $runtime else . end))
			| if .active and (.active.runtime // "") == "" then .active.runtime = $runtime else . end
		' --arg runtime "$BF_RUNTIME" && BF_COUNT=$((BF_COUNT + 1))
	done

	: >"$RUNTIME_MARKER"
	LOG_FILE INFO "Recorded the runtime for $BF_COUNT earlier tracker records"
}

case "$ACTION" in
	start | suspend | resume | stop | migrate) ;;
	*)
		printf 'Usage: %s <name> <core> <file> <start|suspend|resume|stop>\n       %s migrate\n' "$0" "$0" >&2
		exit 1
		;;
esac

[ "$ACTION" = migrate ] || [ -n "$FILE" ] || {
	printf 'Error: file path must not be empty\n' >&2
	exit 1
}

command -v jq >/dev/null 2>&1 || {
	LOG_FILE ERROR "jq is required for activity tracking"
	exit 1
}

if [ "$(GET_VAR "config" "boot/device_mode")" = 1 ]; then
	MODE=console
else
	MODE=handheld
fi

case "$CORE:${TRACK_RUNTIME-}" in
	ext-video:*) RUNTIME=wasabi ;;
	*:pickles | *:retroarch | *:external) RUNTIME=$TRACK_RUNTIME ;;
	ext-*:*) RUNTIME=external ;;
	*) RUNTIME=retroarch ;;
esac

BOARD_NAME=$(GET_VAR "device" "board/name")
NOW=$(date +%s 2>/dev/null)
IS_UINT "$NOW" || NOW=0
UPTIME_NOW=$(GET_UPTIME)
BOOT_ID=$(GET_BOOT_ID)
SESSION_ID="$BOOT_ID-$$-$UPTIME_NOW"

NOW_VALID=1
if ! IS_CURRENT_CLOCK_SANE; then
	NOW_VALID=0
	LOG_FILE WARN "System clock is unsafe (epoch $NOW); this call will not record dates"
fi

mkdir -p "$TRACK_DIR" 2>/dev/null || {
	LOG_FILE ERROR "Unable to create activity tracker directory"
	exit 1
}

ACQUIRE_LOCK || exit 1
MIGRATE_LEGACY || LOG_FILE WARN "Legacy playtime migration was incomplete"
BACKFILL_RUNTIME
[ "$NOW_VALID" -eq 1 ] && UPDATE_HIGHWATER

[ "$ACTION" = migrate ] || LOG_FILE INFO "Activity tracker '$ACTION' for '$NAME' (core: $CORE)"

case "$ACTION" in
	start) START_TRACKING ;;
	suspend) SUSPEND_TRACKING ;;
	resume) RESUME_TRACKING ;;
	stop) STOP_TRACKING ;;
esac
