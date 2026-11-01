#!/bin/sh

# Vita Pro device frontend hooks.
# Sourced by init/async/S01init.sh (before muwarn), mux/install.sh and mux/frontend.sh.
# DEVICE_DISPLAY_START needs log.sh. DEVICE_FRONTEND_START also needs boot.sh for
# WAIT_FOR_FIRST_PAINT, and DEVICE_FRONTEND_EXEC needs runtime.sh for EXEC_MUX.

# Early-boot display guard (Vita Pro only).
# The config/system directory must be persistent across warm reboots.
# An IOMMU failure or persistent VP1 interrupt storm causes at most one
# automatic reboot until a healthy boot clears the marker.
VITA_GUARD_DIR=${VITA_GUARD_DIR:-/opt/muos/config/system/vita-display-guard}
VITA_GUARD_HALT=${VITA_GUARD_HALT:-/opt/muos/script/system/halt.sh}
VITA_GUARD_DONE=/run/vita-display-guard-checked
VITA_GUARD_LOCK=/run/vita-display-guard.lock

VITA_GUARD_CRITICAL_IOMMU() {
	# Match the VOP's own IOMMU or DRM errors, not unrelated IOMMU devices.
	# Common DSI command-mode/DCS -110 warnings are intentionally excluded.
	dmesg 2>/dev/null | grep -Eq \
		'rk_iommu 27d07e00\.iommu:.*(Enable stall request timed out|FORCE_RESET command timed out)|rockchip-vop2 27d00000\.vop:.*(Failed to attach iommu device|vp1 failed to attach dma mapping)'
}

VITA_GUARD_IRQ_TOTAL() {
	# IRQ names are shared by VP0/VP1/VP2. The normal sum is only a few
	# dozen in this interval, versus thousands when VP1 becomes wedged.
	awk '
		/27d00000[.]vop/ {
			for (i = 2; i <= NF; i++) {
				if ($i !~ /^[0-9]+$/) break
				sum += $i
			}
		}
		END { printf "%.0f\n", sum + 0 }
	' /proc/interrupts 2>/dev/null
}

VITA_GUARD_IRQ_FLOOD() {
	# Do not mistake a single interrupt spike for a persistent failure.
	# Need at least two of three 200 ms windows over 2,000 interrupts.
	VITA_G_IRQ_FIRST=$(VITA_GUARD_IRQ_TOTAL)
	case "$VITA_G_IRQ_FIRST" in '' | *[!0-9]*) return 1 ;; esac

	VITA_G_IRQ_HIGH=0
	VITA_G_IRQ_DELTAS=
	VITA_G_IRQ_COUNT=0
	while [ "$VITA_G_IRQ_COUNT" -lt 3 ]; do
		sleep 0.2
		VITA_G_IRQ_NEXT=$(VITA_GUARD_IRQ_TOTAL)
		case "$VITA_G_IRQ_NEXT" in '' | *[!0-9]*) return 1 ;; esac
		VITA_G_IRQ_DELTA=$((VITA_G_IRQ_NEXT - VITA_G_IRQ_FIRST))
		[ "$VITA_G_IRQ_DELTA" -lt 0 ] && return 1
		VITA_G_IRQ_DELTAS="${VITA_G_IRQ_DELTAS}${VITA_G_IRQ_DELTA} "
		[ "$VITA_G_IRQ_DELTA" -gt 2000 ] && VITA_G_IRQ_HIGH=$((VITA_G_IRQ_HIGH + 1))
		VITA_G_IRQ_FIRST=$VITA_G_IRQ_NEXT
		VITA_G_IRQ_COUNT=$((VITA_G_IRQ_COUNT + 1))
	done

	[ "$VITA_G_IRQ_HIGH" -ge 2 ]
}

VITA_GUARD_CHECK() {
	VITA_G_REASON=
	VITA_G_IRQ_DELTAS=unmeasured

	if VITA_GUARD_CRITICAL_IOMMU; then
		VITA_G_REASON=vop-iommu-failure
		return 1
	fi

	if VITA_GUARD_IRQ_FLOOD; then
		VITA_G_REASON=sustained-vop-interrupt-flood
		return 1
	fi

	# Catch a failure that appears during the interrupt sampling window.
	if VITA_GUARD_CRITICAL_IOMMU; then
		VITA_G_REASON=vop-iommu-failure
		return 1
	fi
	return 0
}

VITA_GUARD_CAPTURE() {
	VITA_G_FILE=$1
	VITA_G_PHASE=$2
	VITA_G_CAUSE=$3
	{
		printf 'phase=%s\nreason=%s\nirq_deltas_per_200ms=%s\n' \
			"$VITA_G_PHASE" "$VITA_G_CAUSE" "${VITA_G_IRQ_DELTAS:-unmeasured}"
		uname -a
		printf '\n=== uptime ===\n'
		cat /proc/uptime 2>/dev/null
		printf '\n=== VOP IRQs ===\n'
		grep '27d00000.vop' /proc/interrupts 2>/dev/null
		printf '\n=== DRM summary (if mounted) ===\n'
		[ ! -r /sys/kernel/debug/dri/0/summary ] ||
			cat /sys/kernel/debug/dri/0/summary
		printf '\n=== relevant kernel messages ===\n'
		dmesg 2>/dev/null | grep -Ei \
			'27d00000.vop|27d07e00.iommu|27d80000.dsi|panel-simple-dsi|POST_BUF_EMPTY_INTR|vop3_vp_isr|vita-panel' | tail -n 120
	} >"$VITA_G_FILE" 2>/dev/null
}

VITA_GUARD_FAILURE() {
	VITA_G_PHASE=$1
	VITA_G_CAUSE=$2
	LOG_WARN "$0" 0 "DISPLAY" \
		"Vita Pro $VITA_G_PHASE health check failed: $VITA_G_CAUSE (IRQ/200ms: ${VITA_G_IRQ_DELTAS:-n/a})"

	# Never reboot if we cannot persist the attempt marker. Failure to write
	# config state must fail open rather than risk an endless reboot loop.
	if ! mkdir -p "$VITA_GUARD_DIR" 2>/dev/null; then
		LOG_WARN "$0" 0 "DISPLAY" "Persistent guard directory unavailable; continuing startup"
		return 0
	fi

	if [ -e "$VITA_GUARD_DIR/reboot.pending" ]; then
		VITA_GUARD_CAPTURE "$VITA_GUARD_DIR/last-retry.log" "$VITA_G_PHASE" "$VITA_G_CAUSE"
		LOG_WARN "$0" 0 "DISPLAY" "Automatic recovery already attempted; not rebooting again"
		return 0
	fi

	VITA_GUARD_CAPTURE "$VITA_GUARD_DIR/last-failure.log" "$VITA_G_PHASE" "$VITA_G_CAUSE"

	if [ -e "$VITA_GUARD_DIR/disable-reboot" ]; then
		LOG_WARN "$0" 0 "DISPLAY" "Automatic display reboot disabled; continuing startup"
		return 0
	fi

	if [ ! -x "$VITA_GUARD_HALT" ]; then
		LOG_WARN "$0" 0 "DISPLAY" "Safe halt.sh unavailable; continuing startup"
		return 0
	fi

	if ! printf '%s\n' "$VITA_G_CAUSE" >"$VITA_GUARD_DIR/reboot.pending"; then
		LOG_WARN "$0" 0 "DISPLAY" "Cannot persist reboot marker; continuing startup"
		return 0
	fi

	# Persist the guard marker before initiating a safe reboot.
	sync
	LOG_WARN "$0" 0 "DISPLAY" "Requesting one safe warm reboot for Vita Pro display recovery"
	"$VITA_GUARD_HALT" reboot
	# A failed/returned reboot call must not retry automatically.
	LOG_WARN "$0" 0 "DISPLAY" "Safe reboot returned to startup; automatic retry is now inhibited"
	return 0
}

VITA_GUARD_RECOVERED() {
	[ -e "$VITA_GUARD_DIR/reboot.pending" ] || return 0
	VITA_GUARD_CAPTURE "$VITA_GUARD_DIR/last-recovered.log" post-panel healthy
	rm -f "$VITA_GUARD_DIR/reboot.pending"
	LOG_INFO "$0" 0 "DISPLAY" "Vita Pro reboot recovery completed without a detectable display fault"
}

VITA_PANEL_READY=/run/vita-panel-ready
VITA_PANEL_ATTEMPTED=/run/vita-panel-wake-attempted
VITA_PANEL_LOCK=/run/vita-panel-wake.lock

VITA_IOMMU_FAILED() {
	dmesg 2>/dev/null | grep -Eq \
		'27d07e00\.iommu:.*(Enable stall request timed out|FORCE_RESET command timed out)|iommu driver failed to attach the default/blocking domain|failed to attach dma mapping'
}

VITA_PANEL_WAKE_RELEASE() {
	# If an intermediate write failed, make a best-effort attempt to leave the
	# framebuffer unblanked and the panel standby signal high.
	if [ "${PANEL_BLANKED:-0}" -eq 1 ]; then
		printf '0' >"$FB_BLANK" 2>/dev/null || true
		PANEL_BLANKED=0
	fi

	if [ "${PANEL_GPIO_LOW:-0}" -eq 1 ]; then
		printf '1' >"$GPIO_PATH/value" 2>/dev/null || true
		PANEL_GPIO_LOW=0
	fi

	# Only unexport GPIO24 when this function exported it.
	if [ "${GPIO_EXPORTED:-0}" -eq 1 ]; then
		printf '%s' "$GPIO_NUM" >/sys/class/gpio/unexport 2>/dev/null || true
	fi

	rmdir "$PANEL_LOCK" 2>/dev/null || true
}

VITA_PANEL_WAKE() {
	PANEL_READY=$VITA_PANEL_READY
	PANEL_ATTEMPTED=$VITA_PANEL_ATTEMPTED
	PANEL_LOCK=$VITA_PANEL_LOCK
	FB_BLANK=/sys/class/graphics/fb0/blank
	GPIO_NUM=24
	GPIO_PATH=/sys/class/gpio/gpio$GPIO_NUM
	GPIO_EXPORTED=0
	PANEL_BLANKED=0
	PANEL_GPIO_LOW=0

	# The panel sequence is deliberately unconditional: there is no reliable
	# userspace way to determine whether the physical LCD is actually displaying.
	[ -e "$PANEL_READY" ] && return 0
	[ -e "$PANEL_ATTEMPTED" ] && return 0

	# Prevent S01init and the later frontend startup hook from cycling twice.
	if ! mkdir "$PANEL_LOCK" 2>/dev/null; then
		PANEL_WAIT=0
		while [ "$PANEL_WAIT" -lt 100 ]; do
			[ -e "$PANEL_READY" ] && return 0
			[ -e "$PANEL_ATTEMPTED" ] && return 0
			[ ! -d "$PANEL_LOCK" ] && break
			sleep 0.1
			PANEL_WAIT=$((PANEL_WAIT + 1))
		done

		[ -e "$PANEL_READY" ] && return 0
		[ -e "$PANEL_ATTEMPTED" ] && return 0
		mkdir "$PANEL_LOCK" 2>/dev/null || return 0
	fi

	# Wait for the framebuffer blank control and GPIO interface to appear.
	PANEL_WAIT=0
	while [ "$PANEL_WAIT" -lt 100 ]; do
		if [ -w "$FB_BLANK" ] && {
			[ -d "$GPIO_PATH" ] || [ -w /sys/class/gpio/export ];
		}; then
			break
		fi

		sleep 0.1
		PANEL_WAIT=$((PANEL_WAIT + 1))
	done

	if [ ! -w "$FB_BLANK" ] || {
		[ ! -d "$GPIO_PATH" ] && [ ! -w /sys/class/gpio/export ];
	}; then
		LOG_WARN "$0" 0 "DISPLAY" "Vita Pro panel wake interfaces did not appear"
		rmdir "$PANEL_LOCK" 2>/dev/null || true
		return 0
	fi

	# Export GPIO24 only if it is not already exported. Do not unexport a GPIO
	# that was already owned by another part of the system.
	if [ ! -d "$GPIO_PATH" ]; then
		if printf '%s' "$GPIO_NUM" >/sys/class/gpio/export 2>/dev/null; then
			GPIO_EXPORTED=1
		fi

		PANEL_WAIT=0
		while [ ! -d "$GPIO_PATH" ] && [ "$PANEL_WAIT" -lt 20 ]; do
			sleep 0.05
			PANEL_WAIT=$((PANEL_WAIT + 1))
		done
	fi

	if [ ! -w "$GPIO_PATH/direction" ] || [ ! -w "$GPIO_PATH/value" ]; then
		LOG_WARN "$0" 0 "DISPLAY" "Vita Pro standby GPIO did not become writable"
		VITA_PANEL_WAKE_RELEASE
		return 0
	fi

	# The factory bootloader drives the panel supplies low first, raises the VCI
	# rail during prepare, sends the DSI init sequence, then raises STBYB on
	# GPIO0_24. Keep STBYB low until the DSI commands have run.
	if ! printf 'out' >"$GPIO_PATH/direction"; then
		LOG_WARN "$0" 0 "DISPLAY" "Unable to configure Vita Pro standby GPIO"
		VITA_PANEL_WAKE_RELEASE
		return 0
	fi

	# Reserve/attempt exactly one complete panel cycle per boot. If the VOP/IOMMU
	# fails during the cycle, repeating it could leave the display worse off.
	if ! printf '4' >"$FB_BLANK"; then
		LOG_WARN "$0" 0 "DISPLAY" "Unable to blank Vita Pro framebuffer for panel recovery"
		VITA_PANEL_WAKE_RELEASE
		return 0
	fi
	PANEL_BLANKED=1
	: >"$PANEL_ATTEMPTED"
	sleep 1

	if ! printf '0' >"$GPIO_PATH/value"; then
		LOG_WARN "$0" 0 "DISPLAY" "Unable to lower Vita Pro standby GPIO"
		VITA_PANEL_WAKE_RELEASE
		return 0
	fi
	PANEL_GPIO_LOW=1
	sleep 1

	if ! printf '0' >"$FB_BLANK"; then
		LOG_WARN "$0" 0 "DISPLAY" "Unable to unblank Vita Pro framebuffer after panel recovery"
		VITA_PANEL_WAKE_RELEASE
		return 0
	fi
	PANEL_BLANKED=0

	if ! printf '1' >"$GPIO_PATH/value"; then
		LOG_WARN "$0" 0 "DISPLAY" "Unable to raise Vita Pro standby GPIO"
		VITA_PANEL_WAKE_RELEASE
		return 0
	fi
	PANEL_GPIO_LOW=0
	usleep 5000

	# Give the DSI/VOP pipeline time to settle. A successful sysfs sequence does
	# not prove that light is physically reaching the LCD.
	sleep 0.5

	if VITA_IOMMU_FAILED; then
		LOG_WARN "$0" 0 "DISPLAY" "Vita Pro panel sequence completed, but Rockchip IOMMU errors were detected; userspace cannot reset the failed IOMMU domain"
	else
		: >"$PANEL_READY"
		LOG_INFO "$0" 0 "DISPLAY" "Vita Pro panel power and standby sequence completed"
	fi

	VITA_PANEL_WAKE_RELEASE
}

CLEAR_VITA_BOOT_FRAMEBUFFER() {
	WAIT_FOR_FIRST_PAINT 400 || return 0

	FB_DEV=/dev/fb0
	FB_SYS=/sys/class/graphics/fb0
	[ -w "$FB_DEV" ] && [ -r "$FB_SYS/virtual_size" ] && [ -r "$FB_SYS/bits_per_pixel" ] || return 0

	IFS=, read -r FB_WIDTH FB_HEIGHT <"$FB_SYS/virtual_size"
	read -r FB_BPP <"$FB_SYS/bits_per_pixel"
	[ -n "$FB_WIDTH" ] && [ -n "$FB_HEIGHT" ] && [ -n "$FB_BPP" ] || return 0

	FB_SIZE=$((FB_WIDTH * FB_HEIGHT * FB_BPP / 8))
	[ "$FB_SIZE" -gt 0 ] || return 0

	# The Vita's fbdev buffer retains the themed boot logo after SDL takes
	# ownership through DRM. Clear that dormant buffer after the first real
	# frontend frame so it cannot reappear during later DRM handoffs.
	dd if=/dev/zero of="$FB_DEV" bs="$FB_SIZE" count=1 conv=fsync 2>/dev/null ||
		LOG_WARN "$0" 0 "FRONTEND" "Unable to clear the Vita Pro boot framebuffer"
}

VITA_RESERVE_SCANOUT() {
	RESERVE_BIN=/opt/muos/device/bin/vita-scanout-reserve
	RESERVE_PID_FILE=/run/vita-scanout-reserve.pid
	RESERVE_LOG="${MUOS_LOG_DIR:-/opt/muos/log}/vita-scanout-reserve.log"

	if [ -r "$RESERVE_PID_FILE" ]; then
		read -r RESERVE_PID <"$RESERVE_PID_FILE"
		case "$RESERVE_PID" in
			'' | *[!0-9]*) RESERVE_PID= ;;
		esac
		if [ -n "$RESERVE_PID" ] && kill -0 "$RESERVE_PID" 2>/dev/null &&
			[ "$(readlink "/proc/$RESERVE_PID/exe" 2>/dev/null)" = "$RESERVE_BIN" ]; then
			return 0
		fi
		rm -f "$RESERVE_PID_FILE"
	fi

	[ -x "$RESERVE_BIN" ] || {
		LOG_WARN "$0" 0 "FRONTEND" "Vita Pro scanout reservation helper is missing"
		return 0
	}

	# Rockchip's DRM IOVA allocator may give SDL a framebuffer beginning at
	# address zero. Keep a 16 MiB dumb buffer open before the panel cycle and
	# before any frontend DRM client allocates its real framebuffer.
	"$RESERVE_BIN" >>"$RESERVE_LOG" 2>&1 &
	RESERVE_PID=$!
	printf '%s\n' "$RESERVE_PID" >"$RESERVE_PID_FILE"
	sleep 0.1
	if kill -0 "$RESERVE_PID" 2>/dev/null; then
		LOG_INFO "$0" 0 "FRONTEND" "Vita Pro zero-address scanout reserved"
	else
		rm -f "$RESERVE_PID_FILE"
		LOG_WARN "$0" 0 "FRONTEND" "Vita Pro scanout reservation failed"
	fi
}

DEVICE_DISPLAY_START() {
	# S01init invokes this before muwarn and the frontend. Later startup hooks
	# can call it again; the /run guard ensures we evaluate/reboot only once.
	[ -e "$VITA_GUARD_DONE" ] && return 0
	mkdir "$VITA_GUARD_LOCK" 2>/dev/null || return 0

	VITA_RESERVE_SCANOUT

	# Detect a pre-existing bad VOP before the destructive panel blank cycle.
	# A sustained flood here has previously preceded an IOMMU detach timeout.
	if ! VITA_GUARD_CHECK; then
		: >"$VITA_GUARD_DONE"
		rmdir "$VITA_GUARD_LOCK" 2>/dev/null || true
		VITA_GUARD_FAILURE pre-panel "$VITA_G_REASON"
		return 0
	fi

	VITA_PANEL_WAKE

	# Detect failures introduced during the panel unblank/handover.
	if ! VITA_GUARD_CHECK; then
		: >"$VITA_GUARD_DONE"
		rmdir "$VITA_GUARD_LOCK" 2>/dev/null || true
		VITA_GUARD_FAILURE post-panel "$VITA_G_REASON"
		return 0
	fi

	: >"$VITA_GUARD_DONE"
	rmdir "$VITA_GUARD_LOCK" 2>/dev/null || true
	VITA_GUARD_RECOVERED
}

DEVICE_FRONTEND_START() {
	DEVICE_DISPLAY_START
	CLEAR_VITA_BOOT_FRAMEBUFFER &
}

DEVICE_FACTORY_WARNING_START() {
	# muwarn otherwise falls back to SDL's software renderer. Its imported KMS
	# buffers are then assigned address zero on this VOP and appear as coloured
	# noise. Native GLES follows the same working path as the installer frontend.
	SDL_RENDER_DRIVER=opengles2 /opt/muos/frontend/muwarn &
}

DEVICE_FRONTEND_EXEC() (
	# The native GLES renderer keeps every KMS buffer on a valid VOP address.
	# SDL's software renderer still uses GBM here and rotates through an address-
	# zero buffer, producing corrupt colours and missing animated backgrounds.
	export SDL_RENDER_DRIVER=opengles2
	EXEC_MUX "$@"
)
