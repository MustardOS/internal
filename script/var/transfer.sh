#!/bin/sh

THROBBER_WAIT="${THROBBER_WAIT:-1}"

TRANSFER_TAG=""
TRANSFER_LOG=""
TRANSFER_PID=""
TRANSFER_TOTAL=0

TRANSFER_ABORT() {
	[ -n "$TRANSFER_PID" ] && kill -0 "$TRANSFER_PID" 2>/dev/null && kill "$TRANSFER_PID" 2>/dev/null
	TRANSFER_PID=""
}

TRANSFER_IS_UINT() {
	case "$1" in
		'' | *[!0-9]*) return 1 ;;
		*) return 0 ;;
	esac
}

TRANSFER_THROBBER() {
	while kill -0 "$1" 2>/dev/null; do
		if TASK_IS_NATIVE; then
			TASK_PROGRESS "$(wc -l <"$TRANSFER_LOG" 2>/dev/null || printf 0)" "$TRANSFER_TOTAL"
		else
			printf "."
		fi
		sleep "$THROBBER_WAIT"
	done
}

TRANSFER_MEASURE() {
	SRC_ROOT="$1"
	shift

	TRANSFER_TOTAL=0
	TRANSFER_SIZE=0
	TRANSFER_LIST=""

	for M_PATH in "$@"; do
		SRC="$SRC_ROOT/$M_PATH"
		[ -d "$SRC" ] || {
			LOG_INFO "$0" 0 "$TRANSFER_TAG" "$(printf "Skipping '%s', nothing at the source" "$M_PATH")"
			continue
		}

		P_INFO="$(find "$SRC" -type f -exec ls -ln {} + 2>/dev/null |
			awk 'BEGIN { c = 0; b = 0 }
			     /^-/   { c++; b += $5 }
			     END    { printf "%d %d", c, int((b + 1023) / 1024) }')"

		P_COUNT="${P_INFO% *}"
		P_SIZE="${P_INFO#* }"

		TRANSFER_IS_UINT "$P_COUNT" || P_COUNT=0
		TRANSFER_IS_UINT "$P_SIZE" || P_SIZE=0

		TRANSFER_TOTAL=$((TRANSFER_TOTAL + P_COUNT))
		TRANSFER_SIZE=$((TRANSFER_SIZE + P_SIZE))
		TRANSFER_LIST="$TRANSFER_LIST $M_PATH"
	done

	TRANSFER_LIST="${TRANSFER_LIST# }"
}

# TRANSFER_RUN <tag> <log name> <source root> <destination root> <path...>
TRANSFER_RUN() {
	TRANSFER_TAG="$1"
	LOG_NAME="$2"
	SRC_ROOT="$3"
	DST_ROOT="$4"
	shift 4

	[ "$#" -gt 0 ] || {
		LOG_ERROR "$0" 0 "$TRANSFER_TAG" "No path provided"
		TASK_ERROR "bad_arguments" "$(printf "Usage: %s <relative-path>..." "$0")"
		return 1
	}

	for M_PATH in "$@"; do
		case "$M_PATH" in
			/* | *..*)
				LOG_ERROR "$0" 0 "$TRANSFER_TAG" "$(printf "Invalid path: '%s'" "$M_PATH")"
				TASK_ERROR "bad_path" "$(printf "Invalid path '%s', it must be relative" "$M_PATH")"
				return 1
				;;
		esac
	done

	# Both directions need the secondary card, either as the source or the target
	SD_DEVICE="$(GET_VAR "device" "storage/sdcard/dev")$(GET_VAR "device" "storage/sdcard/sep")$(GET_VAR "device" "storage/sdcard/num")"
	if ! grep -q -m 1 "$SD_DEVICE" /proc/partitions; then
		LOG_ERROR "$0" 0 "$TRANSFER_TAG" "Secondary storage not detected"
		TASK_ERROR "no_sdcard" "Secondary storage was not detected."
		return 1
	fi

	TASK_STATUS "Measuring Content"

	TRANSFER_MEASURE "$SRC_ROOT" "$@"

	if [ -z "$TRANSFER_LIST" ]; then
		LOG_ERROR "$0" 0 "$TRANSFER_TAG" "No source directory exists for any requested path"
		TASK_ERROR "source_missing" "There was nothing at the source to copy"
		return 1
	fi

	DST_SPACE="$(df -k "$DST_ROOT" | awk 'NR==2 { print $4; exit }')"

	if ! TRANSFER_IS_UINT "$DST_SPACE"; then
		LOG_ERROR "$0" 0 "$TRANSFER_TAG" "$(printf "Unable to determine available space on '%s'" "$DST_ROOT")"
		TASK_ERROR "space_unknown" "$(printf "Could not determine free space on '%s'" "$DST_ROOT")"
		return 1
	fi

	# A 5 percent margin covers filesystem overhead, and matters most going back
	# to the boot card where filling it stops the frontend starting again
	NEEDED=$((TRANSFER_SIZE + TRANSFER_SIZE / 20))
	if [ "$DST_SPACE" -lt "$NEEDED" ]; then
		LOG_ERROR "$0" 0 "$TRANSFER_TAG" "$(printf "Insufficient space - required: %s KB, available: %s KB" "$NEEDED" "$DST_SPACE")"
		TASK_ERROR "no_space" "$(printf "Not enough space, %s KB needed but only %s KB free" "$NEEDED" "$DST_SPACE")"
		return 1
	fi

	LOG_INFO "$0" 0 "$TRANSFER_TAG" "$(printf "Found %s files (%s KB)" "$TRANSFER_TOTAL" "$TRANSFER_SIZE")"
	TASK_DETAIL "$(printf "Found %s files (%s KB)" "$TRANSFER_TOTAL" "$TRANSFER_SIZE")"

	for M_PATH in $TRANSFER_LIST; do
		DST="$DST_ROOT/$M_PATH"
		[ -d "$DST" ] && continue

		LOG_INFO "$0" 0 "$TRANSFER_TAG" "$(printf "Creating destination directory: '%s'" "$DST")"
		mkdir -p "$DST" || {
			LOG_ERROR "$0" 0 "$TRANSFER_TAG" "$(printf "Failed to create destination: '%s'" "$DST")"
			TASK_ERROR "mkdir_failed" "$(printf "Could not create '%s'" "$DST")"
			return 1
		}
	done

	TRANSFER_LOG="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/$LOG_NAME"
	TRANSFER_LOG_DIR="${TRANSFER_LOG%/*}"

	mkdir -p "$TRANSFER_LOG_DIR" || {
		TASK_ERROR "log_failed" "$(printf "Could not create the log directory '%s'" "$TRANSFER_LOG_DIR")"
		return 1
	}

	: >"$TRANSFER_LOG" || {
		TASK_ERROR "log_failed" "$(printf "Could not write the log file '%s'" "$TRANSFER_LOG")"
		return 1
	}

	TASK_STATUS "Copying Files"

	(
		for M_PATH in $TRANSFER_LIST; do
			rsync --archive --itemize-changes --log-file="$TRANSFER_LOG" \
				"$SRC_ROOT/$M_PATH/" "$DST_ROOT/$M_PATH/" || exit 1
		done
	) >/dev/null 2>&1 &
	TRANSFER_PID="$!"

	TRANSFER_THROBBER "$TRANSFER_PID"
	wait "$TRANSFER_PID"
	TRANSFER_STATUS="$?"
	TRANSFER_PID=""

	if [ "$TRANSFER_STATUS" -ne 0 ]; then
		LOG_ERROR "$0" 0 "$TRANSFER_TAG" "$(printf "rsync failed with status %s - see '%s'" "$TRANSFER_STATUS" "$TRANSFER_LOG")"
		TASK_ERROR "rsync_failed" "$(printf "Copy failed with status %s, see '%s'" "$TRANSFER_STATUS" "$TRANSFER_LOG")"
		return 1
	fi

	return 0
}
