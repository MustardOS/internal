#!/bin/sh
# GKD Pixel 2 power key listener.
#
# The stock kernel has no rk805-pwrkey driver, so muhotkey never gets a power
# event (board.c has pwr_event = nop). With the out-of-tree module loaded this
# reads the "rk805 pwrkey" input device directly:
#
#   tap   -> SLEEP_SHORT into the hotkey FIFO on release, so hotkey.sh applies
#            its usual guards (recent wake, caffeine, normal mode)
#   hold  -> left to the PMIC's own long-press power cut, as on the H700 boards.
#            It fires at or before 5 s (OFF_SOURCE 0xf6 reads 0x04 afterwards),
#            which is too soon for a software hold-to-shutdown to beat it.
#
# Usage: pwrkey.sh [start]

. /opt/muos/script/var/func.sh

KEY_NAME="rk805 pwrkey"
HOTKEY_FIFO="$MUOS_RUN_DIR/hotkey"
PWRKEY_TRACE="$MUOS_LOG_DIR/pwrkey.trace"

# type EV_KEY (1) | code KEY_POWER (116) << 16, as od prints it
POWER_EVENT=7602177

FIND_EVENT() {
	for N in /sys/class/input/event*; do
		[ "$(cat "$N/device/name" 2>/dev/null)" = "$KEY_NAME" ] && {
			printf '/dev/input/%s' "${N##*/}"
			return 0
		}
	done
	return 1
}

# Always kept, like wake.trace: a short ring of what the key did and when
TRACE() {
	printf '%s %s %s\n' "$(date '+%H:%M:%S')" "$(cut -d ' ' -f 1 /proc/uptime)" "$*" >>"$PWRKEY_TRACE"
	if [ "$(wc -l <"$PWRKEY_TRACE")" -gt 50 ] 2>/dev/null; then
		tail -n 50 "$PWRKEY_TRACE" >"$PWRKEY_TRACE.tmp" && mv -f "$PWRKEY_TRACE.tmp" "$PWRKEY_TRACE"
	fi
}

# module.sh loads the module just before starting this; wait for the input device.
TRY=0
until DEV=$(FIND_EVENT); do
	TRY=$((TRY + 1))
	[ "$TRY" -ge 50 ] && {
		LOG_WARN "$0" 0 "PWRKEY" "No '$KEY_NAME' input device, power key stays inactive"
		exit 0
	}
	sleep 0.2
done

LOG_INFO "$0" 0 "PWRKEY" "Listening on $DEV"
TRACE "listening on $DEV"

exec 4<"$DEV"
while :; do
	# One input_event is 24 bytes: sec, usec (8 each), type+code, value.
	set -- $(dd bs=24 count=1 <&4 2>/dev/null | od -An -t d4)

	# Nothing read: the input device went away (module unloaded), so find it again
	if [ "$#" -eq 0 ]; then
		TRACE "input device gone, waiting for it to return"
		exec 4<&-
		until DEV=$(FIND_EVENT); do sleep 1; done
		exec 4<"$DEV"
		TRACE "listening on $DEV"
		continue
	fi

	[ "$#" -eq 6 ] || continue
	[ "$5" -eq "$POWER_EVENT" ] || continue

	case "$6" in
		1) TRACE "down" ;;
		0)
			# The listener starts early in boot, so ignore taps until the frontend is up
			if [ ! -e "$BOOT_PROGRESS_DONE" ]; then
				TRACE "up, tap ignored (still booting)"
				continue
			fi
			TRACE "up, tap"
			[ -p "$HOTKEY_FIFO" ] && printf 'SLEEP_SHORT\n' >"$HOTKEY_FIFO"
			;;
	esac
done
