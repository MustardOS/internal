#!/bin/sh

. /opt/muos/script/var/func.sh

SS_LOCK="/run/muos/screenshot.lock"
SS_LOCK_HELD=0

SS_CLEANUP() {
	if [ "$SS_LOCK_HELD" -eq 1 ]; then
		rm -f "$SS_LOCK/pid" "$SS_LOCK/start" 2>/dev/null
		rmdir "$SS_LOCK" 2>/dev/null
	fi
}

SS_ACQUIRE_LOCK() {
	if mkdir "$SS_LOCK" 2>/dev/null; then
		SS_LOCK_HELD=1
	else
		SS_PID=$(cat "$SS_LOCK/pid" 2>/dev/null)
		SS_START=$(cat "$SS_LOCK/start" 2>/dev/null)
		SS_CURRENT_START=""
		case "$SS_PID" in '' | *[!0-9]*) ;; *) SS_CURRENT_START=$(awk '{print $22}' "/proc/$SS_PID/stat" 2>/dev/null) ;; esac
		[ -n "$SS_CURRENT_START" ] && [ "$SS_CURRENT_START" = "$SS_START" ] && return 1
		rm -f "$SS_LOCK/pid" "$SS_LOCK/start" 2>/dev/null
		rmdir "$SS_LOCK" 2>/dev/null || return 1
		mkdir "$SS_LOCK" 2>/dev/null || return 1
		SS_LOCK_HELD=1
	fi

	printf '%s\n' "$$" >"$SS_LOCK/pid" || return 1
	awk '{print $22}' "/proc/$$/stat" >"$SS_LOCK/start" 2>/dev/null || return 1
	return 0
}

trap 'SS_CLEANUP' EXIT
trap 'exit 1' HUP INT TERM

if ! SS_ACQUIRE_LOCK; then
	LOG_DEBUG "$0" 0 "SCREENSHOT" "Screenshot already in progress - skipping"
	exit 0
fi

LOG_INFO "$0" 0 "SCREENSHOT" "Capturing screenshot"
RUMBLE "$(GET_VAR "device" "board/rumble")" 0.3

BASE_DIR="$MUOS_STORE_DIR/screenshot"
CURRENT_DATE="$(date +"%Y%m%d_%H%M")"
INDEX=0

while :; do
	SS_FILE="${BASE_DIR}/muOS_${CURRENT_DATE}_${INDEX}.png"
	[ ! -f "$SS_FILE" ] && break
	INDEX=$((INDEX + 1))
done

LOG_DEBUG "$0" 0 "SCREENSHOT" "$(printf "Output file: '%s'" "$SS_FILE")"

case "$(GET_VAR "device" "board/name")" in
	mgx*) /opt/muos/frontend/mufbset -g "$SS_FILE" && convert "$SS_FILE" -rotate 270 "$SS_FILE" ;;
	rg-vita* | rg28xx-h) /opt/muos/frontend/mufbset -g "$SS_FILE" && convert "$SS_FILE" -rotate 90 "$SS_FILE" ;;
	*) /opt/muos/frontend/mufbset -g "$SS_FILE" ;;
esac || {
	LOG_ERROR "$0" 0 "SCREENSHOT" "Screenshot capture failed"
	exit 1
}

LOG_SUCCESS "$0" 0 "SCREENSHOT" "$(printf "Screenshot saved: '%s'" "$SS_FILE")"
