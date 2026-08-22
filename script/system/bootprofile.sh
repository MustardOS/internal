#!/bin/sh
# shellcheck source=/dev/null
# Prints where the last boot spent its time.

[ -n "$MUOS_FUNC_LOADED" ] || . /opt/muos/script/var/func.sh

BOOT_STATUS_DIR="$MUOS_RUN_DIR/boot"
BOOT_STATE_DIR="${BOOT_STATE_DIR:-$MUOS_CONF_SYSTEM/boot}"
DMESG_SNAPSHOT="/run/dmesg_early.log"
FIRST_PAINT_MARKER="$MUOS_RUN_DIR/first_paint"
LOADING_PAINT_MARKER="$MUOS_RUN_DIR/loading_paint"

SLOW_THRESHOLD="0.50"

HZ=$(getconf CLK_TCK 2>/dev/null)
case "$HZ" in
	'' | *[!0-9]*) HZ=100 ;;
esac

SCRIPT_ROWS() {
	[ -d "$BOOT_STATUS_DIR" ] || return 1

	for STATUS_FILE in "$BOOT_STATUS_DIR"/start_*.status; do
		[ -f "$STATUS_FILE" ] || continue

		SP_NAME=${STATUS_FILE##*/start_}
		SP_NAME=${SP_NAME%.status}

		SP_START=
		SP_FINISH=
		SP_STATUS=
		while IFS='=' read -r SP_KEY SP_VAL; do
			case "$SP_KEY" in
				start) SP_START=$SP_VAL ;;
				finish) SP_FINISH=$SP_VAL ;;
				status) SP_STATUS=$SP_VAL ;;
			esac
		done <"$STATUS_FILE"

		if [ -z "$SP_START" ] || [ -z "$SP_FINISH" ]; then
			continue
		fi

		printf '%s\t%s\t%s\t%s\n' "$SP_START" "$SP_FINISH" "${SP_STATUS:-?}" "$SP_NAME"
	done
}

SHOW_SCRIPTS() {
	printf '\n== init scripts, slowest first ==\n'
	printf '%9s  %9s  %9s  %6s  %s\n' "START" "FINISH" "ELAPSED" "STATUS" "SCRIPT"

	SCRIPT_ROWS | awk -F'\t' '
		{ printf "%9.2f  %9.2f  %9.2f  %6s  %s\n", $1, $2, $2 - $1, $3, $4 }
	' | sort -k3 -rn
}

SHOW_TIMELINE() {
	printf '\n== boot timeline ==\n'

	SCRIPT_ROWS | awk -F'\t' -v width=44 '
		{ start[NR] = $1; finish[NR] = $2; name[NR] = $4; if ($2 > span) span = $2 }
		END {
			if (NR == 0) { print "  no recorded boot found"; exit }
			for (i = 1; i <= NR; i++) order[i] = i
			# insertion sort by start time, small n and no external sort needed
			for (i = 2; i <= NR; i++) {
				k = order[i]
				for (j = i - 1; j >= 1 && start[order[j]] > start[k]; j--) order[j + 1] = order[j]
				order[j + 1] = k
			}
			for (i = 1; i <= NR; i++) {
				r = order[i]
				lead = int(start[r] / span * width)
				len = int((finish[r] - start[r]) / span * width)
				if (len < 1) len = 1
				bar = ""
				for (c = 0; c < lead; c++) bar = bar " "
				for (c = 0; c < len; c++) bar = bar "#"
				printf "  %-18s %6.2f %6.2f  %s\n", name[r], start[r], finish[r] - start[r], bar
			}
			printf "\n  span 0 to %.2fs\n", span
		}
	'
}

SHOW_SLOW() {
	printf '\n== over %ss ==\n' "$SLOW_THRESHOLD"

	SCRIPT_ROWS | awk -F'\t' -v limit="$SLOW_THRESHOLD" '
		($2 - $1) > limit { printf "  %-18s %6.2fs\n", $4, $2 - $1; hit++ }
		END { if (!hit) printf "  nothing over the threshold\n" }
	' | sort -k2 -rn
}

SHOW_PROCS() {
	printf '\n== surviving processes, by start time ==\n'

	for PROC_DIR in /proc/[0-9]*; do
		PROC_COMM=$(cat "$PROC_DIR/comm" 2>/dev/null) || continue
		PROC_START=$(awk '{ print $22 }' "$PROC_DIR/stat" 2>/dev/null)
		[ -n "$PROC_START" ] || continue

		printf '%s\t%s\t%s\n' "$PROC_START" "${PROC_DIR#/proc/}" "$PROC_COMM"
	done | sort -n | awk -F'\t' -v hz="$HZ" '
		{ printf "  %8.2f  %-7s %s\n", $1 / hz, $2, $3 }
	'
}

SHOW_KERNEL() {
	printf '\n== kernel gaps over 30ms ==\n'

	if [ -r "$DMESG_SNAPSHOT" ]; then
		KERNEL_SRC=$DMESG_SNAPSHOT
	else
		KERNEL_SRC=
	fi

	{
		if [ -n "$KERNEL_SRC" ]; then
			cat "$KERNEL_SRC"
		else
			dmesg 2>/dev/null
		fi
	} | awk '
		match($0, /^\[ *[0-9]+\.[0-9]+\]/) {
			stamp = substr($0, RSTART + 1, RLENGTH - 2) + 0
			if (prev != "" && stamp - prev > 0.03) {
				printf "  %6.3fs before %.3f  %s\n", stamp - prev, stamp, substr($0, RLENGTH + 2, 78)
			}
			prev = stamp
		}
	' | sort -rn | head -15

	[ -n "$KERNEL_SRC" ] || printf '\n  (live ring buffer, early messages may have wrapped)\n'
}

SHOW_SUMMARY() {
	printf '== summary ==\n'

	read -r UP_NOW _ </proc/uptime 2>/dev/null || UP_NOW="?"
	printf '  uptime now          %ss\n' "$UP_NOW"

	FRONTEND_PID=$(pgrep -f '/opt/muos/frontend/muxfrontend' 2>/dev/null | head -n 1)
	if [ -n "$FRONTEND_PID" ] && [ -r "/proc/$FRONTEND_PID/stat" ]; then
		FRONTEND_TICKS=$(awk '{ print $22 }' "/proc/$FRONTEND_PID/stat")
		printf '  frontend started at %ss\n' "$(awk -v t="$FRONTEND_TICKS" -v hz="$HZ" 'BEGIN { printf "%.2f", t / hz }')"
	else
		printf '  frontend           not running\n'
	fi

	if [ -r "$LOADING_PAINT_MARKER" ]; then
		read -r LOADING_AT _ <"$LOADING_PAINT_MARKER"
		printf '  progress screen     %ss\n' "$LOADING_AT"
	fi

	if [ -r "$FIRST_PAINT_MARKER" ]; then
		read -r PAINT_AT _ <"$FIRST_PAINT_MARKER"
		printf '  FIRST PAINT         %ss\n' "$PAINT_AT"
	else
		printf '  first paint         not recorded\n'
	fi

	SCRIPT_ROWS | awk -F'\t' '
		{ if ($2 > last) last = $2; total += $2 - $1; n++ }
		END {
			if (n) printf "  last init script    %.2fs\n  scripts recorded    %d\n", last, n
		}
	'

	BOOT_COUNT=0
	[ -r "$BOOT_STATE_DIR/attempt_count" ] && read -r BOOT_COUNT <"$BOOT_STATE_DIR/attempt_count" 2>/dev/null

	printf '  boot attempts       %s\n' "${BOOT_COUNT:-0}"
	printf '  boot confirmed      %s\n' "$([ -e "$BOOT_CONFIRMED_FLAG" ] && printf yes || printf 'no')"

	if [ -e "$SAFE_MODE_FLAG" ]; then
		printf '  SAFE MODE           ACTIVE - optional services skipped this boot\n'
	else
		printf '  safe mode           off\n'
	fi
}

case "${1:-timeline}" in
	timeline)
		SHOW_SUMMARY
		SHOW_TIMELINE
		SHOW_SLOW
		;;
	scripts) SHOW_SCRIPTS ;;
	kernel) SHOW_KERNEL ;;
	procs) SHOW_PROCS ;;
	slow) SHOW_SLOW ;;
	all)
		SHOW_SUMMARY
		SHOW_TIMELINE
		SHOW_SCRIPTS
		SHOW_KERNEL
		SHOW_PROCS
		;;
	*)
		printf 'Usage: %s {timeline|scripts|kernel|procs|slow|all}\n' "$0" >&2
		exit 1
		;;
esac

exit 0
