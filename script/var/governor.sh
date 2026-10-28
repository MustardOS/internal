#!/bin/sh

[ -n "${MUOS_GOVERNOR_LOADED-}" ] && return 0
MUOS_GOVERNOR_LOADED=1
[ -n "${MUOS_CONFIG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/config.sh"
[ -n "${MUOS_LOG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/log.sh"

SYNC_GPU_FREQUENCY() {
	GOV="$1"

	# Zero or unset uses every frequency the GPU offers, otherwise it is the chosen ceiling
	GPU_CAP="$(GET_VAR "config" "danger/gpu_max")"
	case "$GPU_CAP" in
		'' | 0 | *[!0-9]*) GPU_CAP="$(GET_VAR "device" "gpu/max_freq_default")" ;;
	esac
	case "$GPU_CAP" in
		'' | *[!0-9]*) GPU_CAP= ;;
	esac

	for GPU_DEV in /sys/class/devfreq/*/; do
		case "$GPU_DEV" in
			*gpu*) ;;
			*) continue ;;
		esac

		[ -w "$GPU_DEV/min_freq" ] || continue
		[ -r "$GPU_DEV/available_frequencies" ] || continue

		GPU_LIST=$(tr ' ' '\n' <"$GPU_DEV/available_frequencies" | grep -v '^$' | sort -n)
		[ -n "$GPU_CAP" ] && GPU_LIST=$(printf "%s\n" "$GPU_LIST" | awk -v c="$GPU_CAP" '$1 + 0 <= c + 0')

		GPU_CEIL=$(printf "%s\n" "$GPU_LIST" | tail -1)
		GPU_FLOOR=$(printf "%s\n" "$GPU_LIST" | head -1)

		GPU_TARGET=$GPU_FLOOR
		GPU_MAX=$GPU_CEIL
		case "$GOV" in
			performance) GPU_TARGET=$GPU_CEIL ;;
			powersave) GPU_MAX=$GPU_FLOOR ;;
		esac

		[ -n "$GPU_TARGET" ] || continue

		if [ -w "$GPU_DEV/max_freq" ]; then
			printf "%s" "$GPU_FLOOR" >"$GPU_DEV/min_freq"
			printf "%s" "$GPU_MAX" >"$GPU_DEV/max_freq"
		fi

		LOG_DEBUG "$0" 0 "FRONTEND" "$(printf "GPU floor set to %s, ceiling %s, for governor '%s'" "$GPU_TARGET" "$GPU_MAX" "$GOV")"
		printf "%s" "$GPU_TARGET" >"$GPU_DEV/min_freq"
	done
}

SYNC_CPU_IDLE() {
	GOV="$1"

	[ -d /sys/devices/system/cpu/cpu0/cpuidle ] || return 0

	if [ "$GOV" = "performance" ]; then
		IDLE_OFF=1
	else
		IDLE_OFF=0
	fi

	for CPU_IDLE_STATE in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
		[ -w "$CPU_IDLE_STATE" ] || continue

		case "$CPU_IDLE_STATE" in
			*/state0/*) continue ;;
		esac

		printf "%s" "$IDLE_OFF" >"$CPU_IDLE_STATE" 2>/dev/null
	done

	LOG_DEBUG "$0" 0 "FRONTEND" "$(printf "Deep CPU idle %s for governor '%s'" \
		"$([ "$IDLE_OFF" -eq 1 ] && echo disabled || echo enabled)" "$GOV")"
}

# Only boards that name their memory devfreq node in board/dmc are touched.
SYNC_DMC_FREQUENCY() {
	GOV="$1"
	DMC_DEV="$(GET_VAR "device" "board/dmc")"
	DMC_SAVED="$MUOS_RUN_DIR/dmc_governor"

	[ -n "$DMC_DEV" ] && [ -w "$DMC_DEV/governor" ] || return 0

	if [ "$GOV" = "performance" ]; then
		[ -s "$DMC_SAVED" ] || cat "$DMC_DEV/governor" >"$DMC_SAVED"
		printf "performance" >"$DMC_DEV/governor"
	elif [ -s "$DMC_SAVED" ]; then
		cat "$DMC_SAVED" >"$DMC_DEV/governor"
		rm -f "$DMC_SAVED"
	fi

	LOG_DEBUG "$0" 0 "FRONTEND" "$(printf "Memory governor '%s' for governor '%s'" "$(cat "$DMC_DEV/governor")" "$GOV")"
}

SYNC_CPU_CORES() {
	REQUESTED_CORES=$(GET_VAR "config" "danger/online_cores")
	case "$REQUESTED_CORES" in
		'' | *[!0-9]*) REQUESTED_CORES=0 ;;
	esac

	DETECTED_CORES=0
	for CPU_DIR in /sys/devices/system/cpu/cpu[0-9]*; do
		[ -d "$CPU_DIR" ] || continue
		CPU_NUMBER=${CPU_DIR##*/cpu}
		case "$CPU_NUMBER" in
			'' | *[!0-9]*) continue ;;
		esac
		DETECTED_CORES=$((DETECTED_CORES + 1))
	done

	[ "$DETECTED_CORES" -gt 0 ] || return 0

	if [ "$REQUESTED_CORES" -eq 0 ] || [ "$REQUESTED_CORES" -gt "$DETECTED_CORES" ]; then
		TARGET_CORES=$DETECTED_CORES
	else
		TARGET_CORES=$REQUESTED_CORES
	fi
	[ "$TARGET_CORES" -ge 1 ] || TARGET_CORES=1

	for CPU_DIR in /sys/devices/system/cpu/cpu[0-9]*; do
		[ -d "$CPU_DIR" ] || continue
		CPU_NUMBER=${CPU_DIR##*/cpu}
		case "$CPU_NUMBER" in
			'' | 0 | *[!0-9]*) continue ;;
		esac

		ONLINE_PATH="$CPU_DIR/online"
		[ -w "$ONLINE_PATH" ] || continue

		if [ "$CPU_NUMBER" -lt "$TARGET_CORES" ]; then
			TARGET_ONLINE=1
		else
			TARGET_ONLINE=0
		fi

		CURRENT_ONLINE=$(cat "$ONLINE_PATH" 2>/dev/null || printf '%s' -1)
		[ "$CURRENT_ONLINE" = "$TARGET_ONLINE" ] && continue

		printf '%s' "$TARGET_ONLINE" >"$ONLINE_PATH" 2>/dev/null ||
			LOG_WARN "$0" 0 "FRONTEND" "$(printf 'Unable to set CPU %s online state to %s' "$CPU_NUMBER" "$TARGET_ONLINE")"
	done

	ONLINE_CORES=1
	for ONLINE_PATH in /sys/devices/system/cpu/cpu[1-9]*/online; do
		[ -r "$ONLINE_PATH" ] || continue
		[ "$(cat "$ONLINE_PATH" 2>/dev/null)" = 1 ] && ONLINE_CORES=$((ONLINE_CORES + 1))
	done

	LOG_DEBUG "$0" 0 "FRONTEND" "$(printf 'Processor cores online: %s of %s (requested: %s)' \
		"$ONLINE_CORES" "$DETECTED_CORES" "$REQUESTED_CORES")"
}

APPLY_PERFORMANCE() {
	MUCPU_BIN=/opt/muos/frontend/mucpu
	[ -x "$MUCPU_BIN" ] || return 1

	PERF_GOV=$("$MUCPU_BIN" apply "${1:-default}" 2>/dev/null)
	[ -n "$PERF_GOV" ] || PERF_GOV=$("$MUCPU_BIN" apply default 2>/dev/null)

	if [ -z "$PERF_GOV" ]; then
		LOG_WARN "$0" 0 "FRONTEND" "$(printf "Unable to apply performance '%s'" "${1:-default}")"
		return 1
	fi

	SYNC_GPU_FREQUENCY "$PERF_GOV"
	SYNC_CPU_IDLE "$PERF_GOV"
	SYNC_DMC_FREQUENCY "$PERF_GOV"

	LOG_DEBUG "$0" 0 "FRONTEND" "$(printf "Performance '%s' applied with governor '%s'" "${1:-default}" "$PERF_GOV")"
}

REAPPLY_PERFORMANCE() {
	MUCPU_BIN=/opt/muos/frontend/mucpu
	[ -x "$MUCPU_BIN" ] || return 1

	PERF_GOV=$("$MUCPU_BIN" reapply 2>/dev/null)
	[ -n "$PERF_GOV" ] || return 1

	SYNC_GPU_FREQUENCY "$PERF_GOV"
	SYNC_CPU_IDLE "$PERF_GOV"
	SYNC_DMC_FREQUENCY "$PERF_GOV"
}

SET_DEFAULT_GOVERNOR() {
	(
		APPLY_PERFORMANCE default

		# Anything a crashed or interrupted session left pinned is released above,
		# so an idle wake must not pin it again.
		rm -f "$MUOS_RUN_DIR/idle_devfreq"

		SYNC_CPU_CORES
	) &
}
