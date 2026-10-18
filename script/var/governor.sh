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
		'' | 0 | *[!0-9]*) GPU_CAP= ;;
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

		if [ "$GOV" = "performance" ]; then
			GPU_TARGET=$GPU_CEIL
		else
			GPU_TARGET=$GPU_FLOOR
		fi

		[ -n "$GPU_TARGET" ] || continue

		if [ -w "$GPU_DEV/max_freq" ]; then
			printf "%s" "$GPU_FLOOR" >"$GPU_DEV/min_freq"
			printf "%s" "$GPU_CEIL" >"$GPU_DEV/max_freq"
		fi

		LOG_DEBUG "$0" 0 "FRONTEND" "$(printf "GPU floor set to %s, ceiling %s, for governor '%s'" "$GPU_TARGET" "$GPU_CEIL" "$GOV")"
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

SET_DEFAULT_GOVERNOR() {
	(
		DEF_GOV=$(GET_VAR "device" "cpu/default")
		GOV_PATH="$(GET_VAR "device" "cpu/governor")"
		AVAIL_PATH="$(GET_VAR "device" "cpu/available")"

		if [ -f "$AVAIL_PATH" ] && ! grep -qw "$DEF_GOV" "$AVAIL_PATH"; then
			LOG_WARN "$0" 0 "FRONTEND" "$(printf "Governor '%s' unavailable, falling back to ondemand" "$DEF_GOV")"
			DEF_GOV="ondemand"
		fi

		printf "%s" "$DEF_GOV" >"$GOV_PATH"
		SYNC_GPU_FREQUENCY "$DEF_GOV"
		SYNC_CPU_IDLE "$DEF_GOV"
		SYNC_DMC_FREQUENCY "$DEF_GOV"

		# Anything a crashed or interrupted session left pinned is released above,
		# so an idle wake must not pin it again.
		rm -f "$MUOS_RUN_DIR/idle_devfreq"

		CPU_PATH=$(dirname "$GOV_PATH")

		MIN_PATH="$(GET_VAR "device" "cpu/min_freq")"
		MAX_PATH="$(GET_VAR "device" "cpu/max_freq")"

		[ -f "$MIN_PATH" ] && GET_VAR "device" "cpu/min_freq_default" >"$MIN_PATH"

		# Zero or unset uses the highest frequency the CPU offers, otherwise it is the chosen ceiling
		CPU_FREQ_DIR=$(dirname "$MAX_PATH")
		CPU_TOP=$(tr ' ' '\n' <"$CPU_FREQ_DIR/scaling_available_frequencies" 2>/dev/null | grep -v '^$' | sort -n | tail -1)
		[ -n "$CPU_TOP" ] || CPU_TOP=$(cat "$CPU_FREQ_DIR/cpuinfo_max_freq" 2>/dev/null)
		[ -n "$CPU_TOP" ] || CPU_TOP="$(GET_VAR "device" "cpu/max_freq_default")"

		CPU_CAP="$(GET_VAR "config" "danger/cpu_max")"
		case "$CPU_CAP" in
			'' | 0 | *[!0-9]*) CPU_CAP="$CPU_TOP" ;;
		esac
		[ "$CPU_CAP" -gt "${CPU_TOP:-0}" ] 2>/dev/null && CPU_CAP="$CPU_TOP"

		[ -f "$MAX_PATH" ] && [ -n "$CPU_CAP" ] && printf "%s" "$CPU_CAP" >"$MAX_PATH"

		if [ "$DEF_GOV" = "ondemand" ]; then
			# Detect differing kernel version layout
			if [ -d "$CPU_PATH/ondemand" ]; then
				OD_PATH="$CPU_PATH/ondemand"
			else
				OD_PATH="$CPU_PATH"
			fi

			[ -f "$OD_PATH/sampling_rate" ] && GET_VAR "device" "cpu/sampling_rate_default" >"$OD_PATH/sampling_rate"
			[ -f "$OD_PATH/up_threshold" ] && GET_VAR "device" "cpu/up_threshold_default" >"$OD_PATH/up_threshold"
			[ -f "$OD_PATH/sampling_down_factor" ] && GET_VAR "device" "cpu/sampling_down_factor_default" >"$OD_PATH/sampling_down_factor"
			[ -f "$OD_PATH/io_is_busy" ] && GET_VAR "device" "cpu/io_is_busy_default" >"$OD_PATH/io_is_busy"
		fi

		SYNC_CPU_CORES
	) &
}

