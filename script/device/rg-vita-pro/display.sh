#!/bin/sh

. /opt/muos/script/var/func.sh

# The kernel takes the panel over from uboot while it is still being shown.
# Every so often the VOP output to the DSI panel stalls during that handover.
# That of which floods the panel's video port with POST_BUF_EMPTY interrupts
# (about 115000 a second instead of one a frame) and leaves the screen black.
# Turning the display pipeline off and on again clears it, and blanking fb0
# does exactly that while nothing else has taken over the display...

VOP_NAME="27d00000.vop"
FB_BLANK="/sys/class/graphics/fb0/blank"

SAMPLE_SECONDS=0.1
STALL_THRESHOLD=1000
MAX_ATTEMPTS=3

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

RECOVER() {
	[ -w "$FB_BLANK" ] || return 0
	VOP_STALLED || return 0

	ATTEMPT=1
	while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
		LOG_WARN "$0" 0 "DISPLAY" "$(printf "Panel output stalled, resetting display pipeline (attempt %s)" "$ATTEMPT")"

		printf '4' >"$FB_BLANK"
		sleep 0.1
		printf '0' >"$FB_BLANK"
		sleep 0.2

		if ! VOP_STALLED; then
			LOG_INFO "$0" 0 "DISPLAY" "Panel output recovered"
			return 0
		fi

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

