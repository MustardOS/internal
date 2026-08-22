#!/bin/sh

. /opt/muos/script/var/func.sh

RUN_DIR="$MUOS_RUN_DIR/battery_usage"
CONF_DIR="$MUOS_CONF_GLOBAL/battery_usage"
BATT_CAP="$MUOS_RUN_DIR/battery/capacity"
BATT_CHG="$MUOS_RUN_DIR/battery/charging"

WATCHER_PID_FILE="$RUN_DIR/watcher.pid"

MAX_DELTA=604800
POLL_INTERVAL=60

TIME_FLOOR=1735689600
TIME_CEILING=4102444799

mkdir -p "$RUN_DIR" "$CONF_DIR"

WRITE_ATOMIC() {
	FILE="$1"
	VAL="$2"
	TMP="${FILE}.tmp.$$"

	if ! { printf "%s" "$VAL" >"$TMP" && mv -f "$TMP" "$FILE"; }; then
		rm -f "$TMP"
		return 1
	fi
}

READ_FILE() {
	FILE="$1"
	DEFAULT="${2:-0}"

	[ -r "$FILE" ] || {
		printf "%s" "$DEFAULT"
		return
	}

	IFS= read -r VAL <"$FILE" 2>/dev/null
	CR=$(printf '\r')
	VAL="${VAL%"$CR"}"

	[ -n "$VAL" ] && printf "%s" "$VAL" || printf "%s" "$DEFAULT"
}

IS_UINT() {
	case ${1-} in
		'' | *[!0-9]*) return 1 ;;
		*) return 0 ;;
	esac
}

CLOCK_IS_SANE() {
	IS_UINT "$1" || return 1
	[ "$1" -ge "$TIME_FLOOR" ] && [ "$1" -le "$TIME_CEILING" ]
}

GET_UPTIME() {
	if [ -r /proc/uptime ]; then
		IFS=' ' read -r UPTIME_VALUE _ </proc/uptime
		UPTIME_VALUE=${UPTIME_VALUE%%.*}
		IS_UINT "$UPTIME_VALUE" && {
			printf "%s" "$UPTIME_VALUE"
			return 0
		}
	fi

	printf "0"
}

GET_BOOT_ID() {
	if [ -r /proc/sys/kernel/random/boot_id ]; then
		IFS= read -r BOOT_VALUE </proc/sys/kernel/random/boot_id
		[ -n "$BOOT_VALUE" ] && {
			printf "%s" "$BOOT_VALUE"
			return 0
		}
	fi

	printf "unknown"
}

REPAIR_LAST_CHARGED() {
	CLOCK_IS_SANE "$1" || return 0

	LAST_CHARGED=$(READ_FILE "$CONF_DIR/last_charged_timestamp" "0")
	CLOCK_IS_SANE "$LAST_CHARGED" && return 0

	[ "$2" -gt 0 ] || return 0

	REPAIRED=$(($1 - $2))
	CLOCK_IS_SANE "$REPAIRED" || return 0

	WRITE_ATOMIC "$CONF_DIR/last_charged_timestamp" "$REPAIRED"
	LOG_INFO "$0" 0 "BATTERY_USAGE" "$(printf "Clock is trustworthy again - last_charged corrected to %d" "$REPAIRED")"
}

IS_CHARGING() {
	CHG=$(READ_FILE "$BATT_CHG" "")
	case "$CHG" in
		1) return 0 ;;
		0) return 1 ;;
		*) return 2 ;;
	esac
}

READ_CAPACITY() {
	[ -r "$BATT_CAP" ] || return
	CAP=$(READ_FILE "$BATT_CAP" "")

	case "$CAP" in
		'' | *[!0-9]*) return ;;
	esac

	[ "$CAP" -ge 0 ] && [ "$CAP" -le 100 ] && printf "%s" "$CAP"
}

MARK_MEASUREMENT() {
	WRITE_ATOMIC "$CONF_DIR/last_measurement_timestamp" "$1"
	WRITE_ATOMIC "$CONF_DIR/last_measurement_uptime" "$2"
	WRITE_ATOMIC "$CONF_DIR/last_measurement_boot" "$3"
}

DO_UPDATE() {
	NOW_TS=$(date +%s)
	IS_UINT "$NOW_TS" || NOW_TS=0

	UP_NOW=$(GET_UPTIME)
	BOOT_NOW=$(GET_BOOT_ID)

	LAST_UP=$(READ_FILE "$CONF_DIR/last_measurement_uptime" "")
	LAST_BOOT=$(READ_FILE "$CONF_DIR/last_measurement_boot" "")
	TIME_ON_BATT=$(READ_FILE "$CONF_DIR/time_on_battery" "0")
	LAST_STATE=$(READ_FILE "$CONF_DIR/last_power_state" "")

	if [ "$LAST_BOOT" != "$BOOT_NOW" ] || ! IS_UINT "$LAST_UP" || [ "$UP_NOW" -lt "$LAST_UP" ]; then
		MARK_MEASUREMENT "$NOW_TS" "$UP_NOW" "$BOOT_NOW"
		return
	fi

	DELTA=$((UP_NOW - LAST_UP))

	if [ "$DELTA" -gt "$MAX_DELTA" ]; then
		LOG_WARN "$0" 0 "BATTERY_USAGE" "$(printf "Delta %ds exceeds max %ds - clamping" "$DELTA" "$MAX_DELTA")"
		DELTA=$MAX_DELTA
	fi

	if [ "$LAST_STATE" = "0" ] && [ "$DELTA" -gt 0 ]; then
		TIME_ON_BATT=$((TIME_ON_BATT + DELTA))
		WRITE_ATOMIC "$CONF_DIR/time_on_battery" "$TIME_ON_BATT"
	fi

	REPAIR_LAST_CHARGED "$NOW_TS" "$TIME_ON_BATT"

	MARK_MEASUREMENT "$NOW_TS" "$UP_NOW" "$BOOT_NOW"
}

SYNC_RUNTIME() {
	WRITE_ATOMIC "$RUN_DIR/last_charged" "$(READ_FILE "$CONF_DIR/last_charged_timestamp" "0")"
	WRITE_ATOMIC "$RUN_DIR/time_on_battery" "$(READ_FILE "$CONF_DIR/time_on_battery" "0")"

	UNPLUG_CAP=$(READ_FILE "$CONF_DIR/unplug_capacity" "")
	if [ -n "$UNPLUG_CAP" ]; then
		WRITE_ATOMIC "$RUN_DIR/unplug_capacity" "$UNPLUG_CAP"
	else
		rm -f "$RUN_DIR/unplug_capacity"
	fi
}

DO_EVENT() {
	NOW_TS=$(date +%s)

	if IS_CHARGING; then
		WAS_CHARGING=$(READ_FILE "$CONF_DIR/was_charging" "0")
		if [ "$WAS_CHARGING" != "1" ]; then
			DO_UPDATE
			LOG_INFO "$0" 0 "BATTERY_USAGE" "Charger plugged in - pausing accumulation"

			WRITE_ATOMIC "$CONF_DIR/was_charging" "1"
			WRITE_ATOMIC "$CONF_DIR/last_power_state" "1"
			MARK_MEASUREMENT "$NOW_TS" "$(GET_UPTIME)" "$(GET_BOOT_ID)"
		fi
	else
		WAS_CHARGING=$(READ_FILE "$CONF_DIR/was_charging" "0")
		if [ "$WAS_CHARGING" = "1" ]; then
			LOG_INFO "$0" 0 "BATTERY_USAGE" "$(printf "Charger unplugged - recording last_charged=%d, resetting time_on_battery" "$NOW_TS")"

			if CLOCK_IS_SANE "$NOW_TS"; then
				WRITE_ATOMIC "$CONF_DIR/last_charged_timestamp" "$NOW_TS"
			else
				WRITE_ATOMIC "$CONF_DIR/last_charged_timestamp" "0"
				LOG_WARN "$0" 0 "BATTERY_USAGE" "$(printf "Clock reads %d and is not trustworthy - last_charged left unknown" "$NOW_TS")"
			fi

			WRITE_ATOMIC "$CONF_DIR/time_on_battery" "0"
			MARK_MEASUREMENT "$NOW_TS" "$(GET_UPTIME)" "$(GET_BOOT_ID)"
			WRITE_ATOMIC "$CONF_DIR/was_charging" "0"
			WRITE_ATOMIC "$CONF_DIR/last_power_state" "0"

			CAP=$(READ_CAPACITY)
			if [ -n "$CAP" ]; then
				WRITE_ATOMIC "$CONF_DIR/unplug_capacity" "$CAP"
				LOG_INFO "$0" 0 "BATTERY_USAGE" "$(printf "Capacity at unplug: %d%%" "$CAP")"
			else
				rm -f "$CONF_DIR/unplug_capacity"
			fi

			SYNC_RUNTIME
		fi
	fi
}

DO_WATCH() {
	PREV_CHARGING=""

	while :; do
		if IS_CHARGING; then
			CURR_CHARGING=1
		else
			CURR_CHARGING=0
		fi

		if [ -n "$PREV_CHARGING" ] && [ "$CURR_CHARGING" != "$PREV_CHARGING" ]; then
			DO_EVENT
		elif [ -n "$PREV_CHARGING" ]; then
			DO_UPDATE
			SYNC_RUNTIME
		fi

		PREV_CHARGING="$CURR_CHARGING"
		sleep "$POLL_INTERVAL"
	done
}

DO_INIT() {
	LOG_INFO "$0" 0 "BATTERY_USAGE" "Initialising battery usage tracker"

	WAIT_COUNT=0
	until [ -f "$BATT_CAP" ] && [ -f "$BATT_CHG" ]; do
		sleep 0.1
		WAIT_COUNT=$((WAIT_COUNT + 1))
		if [ "$WAIT_COUNT" -ge 300 ]; then
			LOG_WARN "$0" 0 "BATTERY_USAGE" "Battery files not ready after 30s - continuing anyway"
			break
		fi
	done

	NOW_TS=$(date +%s)
	IS_UINT "$NOW_TS" || NOW_TS=0

	STORED_CHARGED=$(READ_FILE "$CONF_DIR/last_charged_timestamp" "0")
	if [ "$STORED_CHARGED" != "0" ] && ! CLOCK_IS_SANE "$STORED_CHARGED"; then
		LOG_WARN "$0" 0 "BATTERY_USAGE" "$(printf "Stored last_charged %s came from an unset clock - discarding" "$STORED_CHARGED")"
		WRITE_ATOMIC "$CONF_DIR/last_charged_timestamp" "0"
	fi

	REPAIR_LAST_CHARGED "$NOW_TS" "$(READ_FILE "$CONF_DIR/time_on_battery" "0")"

	SYNC_RUNTIME

	if IS_CHARGING; then
		WRITE_ATOMIC "$CONF_DIR/last_power_state" "1"
		WRITE_ATOMIC "$CONF_DIR/was_charging" "1"
	else
		WRITE_ATOMIC "$CONF_DIR/last_power_state" "0"
	fi

	MARK_MEASUREMENT "$NOW_TS" "$(GET_UPTIME)" "$(GET_BOOT_ID)"

	LOG_SUCCESS "$0" 0 "BATTERY_USAGE" "Battery usage tracker initialised - starting watcher"

	DO_WATCH &
	WRITE_ATOMIC "$WATCHER_PID_FILE" "$!"
}

DO_STATUS() {
	LAST_CHARGED=$(READ_FILE "$RUN_DIR/last_charged" "0")
	TIME_ON_BATT=$(READ_FILE "$RUN_DIR/time_on_battery" "0")
	UNPLUG_CAP=$(READ_FILE "$RUN_DIR/unplug_capacity" "")
	CURR_CAP=$(READ_CAPACITY)

	printf "LAST_CHARGED=%s\n" "$LAST_CHARGED"
	printf "TIME_ON_BATTERY=%s\n" "$TIME_ON_BATT"
	[ -n "$UNPLUG_CAP" ] && printf "UNPLUG_CAPACITY=%s\n" "$UNPLUG_CAP"
	[ -n "$CURR_CAP" ] && printf "CURRENT_CAPACITY=%s\n" "$CURR_CAP"
}

DO_SHUTDOWN() {
	LOG_INFO "$0" 0 "BATTERY_USAGE" "Flushing battery usage state before shutdown"
	DO_UPDATE
	SYNC_RUNTIME
	LOG_SUCCESS "$0" 0 "BATTERY_USAGE" "Battery usage state flushed"
}

case "$1" in
	init) DO_INIT ;;
	update)
		DO_UPDATE
		SYNC_RUNTIME
		;;
	event) DO_EVENT ;;
	status) DO_STATUS ;;
	shutdown) DO_SHUTDOWN ;;
	*)
		printf "Usage: %s {init|update|event|status|shutdown}\n" "$0" >&2
		exit 1
		;;
esac
