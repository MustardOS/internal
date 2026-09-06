#!/bin/sh

# shellcheck disable=SC2016

. /opt/muos/script/var/func.sh

JQ_BIN=/usr/bin/jq
STATUS_CR=$(printf '\r')

LANDING_STATE="$MUOS_RUN_DIR/landing/state"
STATUS_FILE="$LANDING_STATE/status.json"
BATTERY_DIR="$MUOS_RUN_DIR/battery"
TRACK_JSON="$MUOS_STORE_DIR/info/track/playtime_data.json"

FAST_SLEEP=5
SLOW_EVERY=12
ACTIVITY_TOP=5

READ_FILE() {
	RF_VALUE=
	[ -r "$1" ] || return 0

	IFS= read -r RF_VALUE <"$1" 2>/dev/null
	printf '%s' "${RF_VALUE%"$STATUS_CR"}"
}

READ_UINT() {
	RU_VALUE=$(READ_FILE "$1")
	case "$RU_VALUE" in
		'' | *[!0-9]*) return 0 ;;
		*) printf '%s' "$RU_VALUE" ;;
	esac
}

IS_MOUNTED() {
	[ -n "$1" ] || return 1
	awk -v want="$1" '$2 == want { found = 1 } END { exit !found }' /proc/mounts 2>/dev/null
}

DISK_KIB() {
	df -k "$1" 2>/dev/null | tail -n 1 |
		awk '{ if (NF >= 5) printf "%s %s", $(NF-4), $(NF-3) }'
}

STORAGE_DOC() {
	SD_OUT=
	for SD_ENTRY in "rom:SD1" "sdcard:SD2" "usb:USB" "root:System"; do
		SD_TYPE=${SD_ENTRY%%:*}
		SD_LABEL=${SD_ENTRY#*:}

		SD_MOUNT=$(GET_VAR "device" "storage/$SD_TYPE/mount")
		IS_MOUNTED "$SD_MOUNT" || continue

		SD_SIZE=$(DISK_KIB "$SD_MOUNT")
		SD_TOTAL=${SD_SIZE%% *}
		SD_USED=${SD_SIZE##* }

		case "$SD_TOTAL:$SD_USED" in
			*[!0-9:]* | :* | *:) continue ;;
		esac

		[ "$SD_TOTAL" -gt 0 ] || continue

		SD_ITEM=$("$JQ_BIN" -n -c \
			--arg name "$SD_LABEL" \
			--arg mount "$SD_MOUNT" \
			--argjson total "$SD_TOTAL" \
			--argjson used "$SD_USED" \
			'{"label": $name, "mount": $mount, "total": ($total * 1024), "used": ($used * 1024)}' 2>/dev/null) || continue

		SD_OUT="${SD_OUT:+$SD_OUT,}$SD_ITEM"
	done

	printf '[%s]' "$SD_OUT"
}

ACTIVITY_DOC() {
	[ -r "$TRACK_JSON" ] || {
		printf 'null'
		return 0
	}

	AD_OUT=$("$JQ_BIN" -c --argjson top "$ACTIVITY_TOP" '
		[to_entries[] | select(.value | type == "object")] as $all
		| {
			"titles": ($all | length),
			"launches": ($all | map(.value.launches // 0) | add // 0),
			"total_time": ($all | map(.value.total_time // 0) | add // 0),
			"top": (
				$all
				| map({
					"name": (.value.name // (.key | split("/") | last // .key)),
					"time": (.value.total_time // 0),
					"launches": (.value.launches // 0)
				})
				| sort_by(-.time)
				| .[0:$top]
			)
		}
	' "$TRACK_JSON" 2>/dev/null) || AD_OUT=
	[ -n "$AD_OUT" ] || AD_OUT=null

	printf '%s' "$AD_OUT"
}

CONTENT_DOC() {
	[ -s "$OVL_GO" ] || {
		printf 'null'
		return 0
	}

	{
		IFS= read -r CD_NAME
		IFS= read -r CD_SYSTEM
		IFS= read -r CD_CORE
	} <"$OVL_GO" 2>/dev/null

	[ -n "${CD_NAME:-}" ] || {
		printf 'null'
		return 0
	}

	CD_OUT=$("$JQ_BIN" -n -c \
		--arg name "$CD_NAME" \
		--arg system "${CD_SYSTEM:-}" \
		--arg core "${CD_CORE:-}" \
		'{"name": $name, "system": $system, "core": $core}' 2>/dev/null) || CD_OUT=
	[ -n "$CD_OUT" ] || CD_OUT=null

	printf '%s' "$CD_OUT"
}

ELAPSED_SINCE() {
	ES_FILE="$MUOS_CONF_SYSTEM/foreground_process"
	[ -s "$OVL_GO" ] && ES_FILE="$OVL_GO"

	ES_MTIME=$(stat -c %Y "$ES_FILE" 2>/dev/null)
	case "$ES_MTIME" in
		'' | *[!0-9]*) return 0 ;;
	esac

	[ "$1" -ge "$ES_MTIME" ] && printf '%s' "$(($1 - ES_MTIME))"
}

DEVICE_ADDRESS() {
	DA_IFACE=$(GET_VAR "device" "network/iface_active")
	[ -n "$DA_IFACE" ] || DA_IFACE=$(GET_VAR "device" "network/iface")
	[ -n "$DA_IFACE" ] || return 0

	ip -4 -o addr show dev "$DA_IFACE" 2>/dev/null |
		awk 'NR == 1 { sub(/\/.*/, "", $4); print $4 }'
}

WRITE_STATUS() {
	IFS=' ' read -r WS_UPTIME _ </proc/uptime 2>/dev/null || WS_UPTIME=0
	WS_UPTIME=${WS_UPTIME%%.*}
	case "$WS_UPTIME" in '' | *[!0-9]*) WS_UPTIME=0 ;; esac

	WS_NOW=$(date '+%s')
	case "$WS_NOW" in '' | *[!0-9]*) WS_NOW=0 ;; esac

	WS_BOOT=
	[ "$WS_NOW" -gt "$WS_UPTIME" ] && WS_BOOT=$(date -d "@$((WS_NOW - WS_UPTIME))" '+%a %d %b, %H:%M' 2>/dev/null)

	WS_ELAPSED=$(ELAPSED_SINCE "$WS_NOW")

	WS_CAPACITY=$(READ_UINT "$BATTERY_DIR/capacity")
	WS_VOLTAGE=$(READ_UINT "$BATTERY_DIR/voltage")
	WS_CHARGING=$(READ_UINT "$BATTERY_DIR/charging")

	WS_WIDTH=$(GET_VAR "device" "screen/width")
	WS_HEIGHT=$(GET_VAR "device" "screen/height")
	WS_SCREEN=
	[ -n "$WS_WIDTH" ] && [ -n "$WS_HEIGHT" ] && WS_SCREEN="${WS_WIDTH}x${WS_HEIGHT}"

	WS_TMP=$(mktemp "$LANDING_STATE/.status.XXXXXX") || return 1

	if "$JQ_BIN" -n \
		--arg clock "$(date '+%H:%M')" \
		--arg day "$(date '+%a %d %b')" \
		--arg zone "$(date '+%Z')" \
		--argjson epoch "$WS_NOW" \
		--argjson uptime "$WS_UPTIME" \
		--arg device "$(GET_VAR "device" "board/name")" \
		--arg version "$(GET_VAR "system" "version")" \
		--arg build "$(GET_VAR "system" "build")" \
		--arg kernel "$(uname -sr 2>/dev/null)" \
		--arg screen "$WS_SCREEN" \
		--argjson capacity "${WS_CAPACITY:-null}" \
		--argjson voltage "${WS_VOLTAGE:-null}" \
		--argjson charging "${WS_CHARGING:-null}" \
		--arg boot "$WS_BOOT" \
		--arg address "$(DEVICE_ADDRESS)" \
		--arg process "$(GET_VAR "system" "foreground_process")" \
		--argjson elapsed "${WS_ELAPSED:-null}" \
		--argjson content "$(CONTENT_DOC)" \
		--argjson storage "$STORAGE_CACHE" \
		--argjson activity "$ACTIVITY_CACHE" \
		'{
			"clock": $clock,
			"day": $day,
			"zone": $zone,
			"epoch": $epoch,
			"uptime": $uptime,
			"boot": $boot,
			"address": $address,
			"device": {
				"name": $device,
				"version": $version,
				"build": $build,
				"kernel": $kernel,
				"screen": $screen
			},
			"battery": {"capacity": $capacity, "voltage": $voltage, "charging": $charging},
			"running": {"process": $process, "elapsed": $elapsed, "content": $content},
			"storage": $storage,
			"activity": $activity
		}' >"$WS_TMP" 2>/dev/null; then
		chmod 0644 "$WS_TMP"
		mv -f "$WS_TMP" "$STATUS_FILE" || {
			rm -f "$WS_TMP"
			return 1
		}
		return 0
	fi

	rm -f "$WS_TMP"
	return 1
}

REFRESH_SLOW() {
	STORAGE_CACHE=$(STORAGE_DOC)
	ACTIVITY_CACHE=$(ACTIVITY_DOC)
}

[ -x "$JQ_BIN" ] || {
	LOG_ERROR "$0" 0 "WEB" "Landing page dashboard needs jq, which is unavailable"
	exit 1
}

mkdir -p "$LANDING_STATE" || exit 1

STORAGE_CACHE='[]'
ACTIVITY_CACHE=null

case "${1:-watch}" in
	once)
		REFRESH_SLOW
		WRITE_STATUS || exit 1
		;;
	watch)
		TICK=0
		while :; do
			[ "$((TICK % SLOW_EVERY))" -eq 0 ] && REFRESH_SLOW
			WRITE_STATUS
			TICK=$((TICK + 1))
			sleep "$FAST_SLEEP"
		done
		;;
	*)
		printf 'Usage: %s {once|watch}\n' "$0" >&2
		exit 1
		;;
esac

exit 0
