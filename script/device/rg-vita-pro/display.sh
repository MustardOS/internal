#!/bin/sh

. /opt/muos/script/var/func.sh

# The kernel takes the panel over from U-Boot while it is still being shown.
# Normalise that handover once before userspace takes ownership of the display.
# This also recovers panels which remain black while the VOP itself continues
# scanning out normally, a state which cannot be inferred from its IRQ count.
# If the VOP still floods POST_BUF_EMPTY interrupts afterwards, repeat the
# bounded reset until the display pipeline settles.

VOP_NAME="27d00000.vop"
FB_BLANK="/sys/class/graphics/fb0/blank"

SAMPLE_SECONDS=0.1
STALL_THRESHOLD=1000
MAX_ATTEMPTS=3
READY_ATTEMPTS=40
READY_DELAY=0.05

VOP_IRQ_TOTAL() {
	awk -v name="$VOP_NAME" '
		index($0, name) {
			for (i = 2; i <= NF; i++) {
				if ($i !~ /^[0-9]+$/) break
				total += $i
			}
		}
		END { print total + 0 }
	' /proc/interrupts
}

VOP_STALLED() {
	BEFORE=$(VOP_IRQ_TOTAL)
	sleep "$SAMPLE_SECONDS"
	AFTER=$(VOP_IRQ_TOTAL)
	[ $((AFTER - BEFORE)) -gt "$STALL_THRESHOLD" ]
}

WAIT_FOR_PANEL() {
	ATTEMPT=0
	while [ "$ATTEMPT" -lt "$READY_ATTEMPTS" ]; do
		[ -w "$FB_BLANK" ] && return 0
		ATTEMPT=$((ATTEMPT + 1))
		sleep "$READY_DELAY"
	done

	return 1
}

RESET_PIPELINE() {
	printf '%s' 4 >"$FB_BLANK" || return 1
	sleep 0.1
	printf '%s' 0 >"$FB_BLANK" || return 1
	sleep 0.2
}

RECOVER() {
	if ! WAIT_FOR_PANEL; then
		LOG_WARN "$0" 0 "DISPLAY" "Panel framebuffer did not become ready for handover recovery"
		return 0
	fi

	WAS_STALLED=0
	if VOP_STALLED; then
		WAS_STALLED=1
		LOG_WARN "$0" 0 "DISPLAY" "Panel output stalled during the U-Boot handover"
	fi

	ATTEMPT=1
	while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
		if ! RESET_PIPELINE; then
			LOG_ERROR "$0" 0 "DISPLAY" "Unable to reset the panel display pipeline"
			return 1
		fi

		if ! VOP_STALLED; then
			if [ "$WAS_STALLED" -eq 1 ]; then
				LOG_INFO "$0" 0 "DISPLAY" "Panel output recovered"
			else
				LOG_INFO "$0" 0 "DISPLAY" "Panel handover normalised"
			fi
			return 0
		fi

		LOG_WARN "$0" 0 "DISPLAY" "$(printf "Panel output remains stalled, retrying display pipeline reset (attempt %s)" "$ATTEMPT")"
		WAS_STALLED=1
		ATTEMPT=$((ATTEMPT + 1))
	done

	LOG_ERROR "$0" 0 "DISPLAY" "Panel output still stalled after resetting display pipeline"
	return 1
}

case "$1" in
	recover) RECOVER ;;
	*)
		printf 'Usage: %s recover\n' "$0" >&2
		exit 1
		;;
esac
