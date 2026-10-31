#!/bin/sh

. /opt/muos/script/var/log.sh

# Observe the display handover from U-Boot without disabling the VOP. The
# RK3576 vendor DRM driver detaches its private IOMMU domain when the VOP is
# disabled, but can fail to reattach it before a DRM client owns the display.
# That failure disables every plane and leaves a lit, black panel. The first
# userspace DRM commit is therefore responsible for completing the handover.

VOP_NAME="27d00000.vop"
FB_BLANK="/sys/class/graphics/fb0/blank"

SAMPLE_SECONDS=0.1
STALL_THRESHOLD=1000
READY_ATTEMPTS=40
READY_DELAY=0.05

TRACE() {
	[ -w /dev/kmsg ] || return 0
	printf '<6>muos-display: %s\n' "$*" >/dev/kmsg
}

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
	DELTA=$((AFTER - BEFORE))
	TRACE "VOP IRQ delta over ${SAMPLE_SECONDS}s: $DELTA"
	[ "$DELTA" -gt "$STALL_THRESHOLD" ]
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

RECOVER() {
	if ! WAIT_FOR_PANEL; then
		TRACE "panel framebuffer did not become ready"
		LOG_WARN "$0" 0 "DISPLAY" "Panel framebuffer did not become ready for handover observation"
		return 0
	fi
	TRACE "observing panel handover"

	if VOP_STALLED; then
		TRACE "VOP interrupt flood detected; preserving the active IOMMU mapping"
		LOG_WARN "$0" 0 "DISPLAY" "Panel handover interrupt flood detected; deferring recovery to the first DRM client"
	else
		TRACE "panel handover scanout is stable"
	fi

	return 0
}

case "$1" in
	recover) RECOVER ;;
	*)
		printf 'Usage: %s recover\n' "$0" >&2
		exit 1
		;;
esac
