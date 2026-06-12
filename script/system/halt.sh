#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")
RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"
RUMBLE_SETTING="$(GET_VAR "config" "settings/advanced/rumble")"

INIT_DIR="/opt/muos/script/init"

USAGE() {
	printf 'Usage: %s {poweroff|reboot}\n' "$0" >&2
	exit 1
}

[ "$#" -eq 1 ] || USAGE
case "$1" in
	poweroff | reboot) ;;
	*) USAGE ;;
esac

ACTION=$1
case "$ACTION" in
	poweroff | shutdown) SHOW_SPLASH shutdown ;;
	*) SHOW_SPLASH "$ACTION" ;;
esac

set --
for OMIT_PID in $(pidof /opt/muos/frontend/muterm /sbin/mount.exfat-fuse 2>/dev/null); do
	set -- "$@" -o "$OMIT_PID"
done

# Runs CMD in its own process group (via setsid) so SIGTERM/SIGKILL reach the
# entire subtree. Falls back from TERM to KILL after the grace period.
#
# Usage: RUN_WITH_TIMEOUT TERM_SEC KILL_SEC CMD [ARG]...
RUN_WITH_TIMEOUT() {
	TERM_SEC=$1
	KILL_SEC=$2
	shift 2

	setsid "$@" &
	CMD_PID=$!

	(
		sleep "$TERM_SEC"
		if kill -0 "$CMD_PID" 2>/dev/null; then
			kill -TERM -"$CMD_PID" 2>/dev/null
			sleep "$KILL_SEC"
			kill -KILL -"$CMD_PID" 2>/dev/null
		fi
	) &
	WATCHDOG_PID=$!

	wait "$CMD_PID"
	CMD_STATUS=$?

	# Cancel the watchdog if the command already exited cleanly.
	kill "$WATCHDOG_PID" 2>/dev/null
	wait "$WATCHDOG_PID" 2>/dev/null

	return "$CMD_STATUS"
}

# Returns a space-separated list of command names for processes outside the
# current session that are not in the omit list. Single awk pass, no temp
# files, no subshell flush race.
#
# Usage: FIND_PROCS [-o OMIT_PID]...
FIND_PROCS() {
	CURRENT_SID=$(cut -d ' ' -f6 /proc/self/stat)
	OMIT_LIST=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-o)
				shift
				OMIT_LIST="$OMIT_LIST $1"
				;;
		esac
		shift
	done

	ps -eo pid=,sid=,comm= | awk \
		-v cur_sid="$CURRENT_SID" \
		-v omit="$OMIT_LIST" \
		'BEGIN {
			n = split(omit, a)
			for (i = 1; i <= n; i++) omit_set[a[i]] = 1
		}
		{
			pid=$1; sid=$2; comm=$3
			if (pid == 1)        next
			if (sid == 0)        next
			if (sid == cur_sid)  next
			if (pid in omit_set) next
			printf "%s ", comm
		}'
}

# Broadcasts SIGNAL to all processes outside the current session, then
# poll until they exit or TIMEOUT_SEC elapses.
#
# Usage: KILL_AND_WAIT TIMEOUT_SEC SIGNAL [-o OMIT_PID]...
KILL_AND_WAIT() {
	TIMEOUT_SEC=$1
	SIGNAL=$2
	shift 2

	killall5 "-$SIGNAL" "$@"

	POLL_COUNT=0
	POLL_MAX=$((TIMEOUT_SEC * 4))
	while [ "$POLL_COUNT" -lt "$POLL_MAX" ]; do
		[ -z "$(FIND_PROCS "$@")" ] && return 0
		sleep 0.25
		POLL_COUNT=$((POLL_COUNT + 1))
	done

	return 1
}

# Iterate one init directory's S??* scripts in reverse order,
# invoking each with `stop` under its own per-script timeout.
#
# Usage: STOP_DIR PATH LABEL
STOP_DIR() {
	DIR=$1
	LABEL=$2

	if [ ! -d "$DIR" ]; then
		LOG_WARN "$0" 0 "HALT" "$(printf "Skipping %s: %s does not exist" "$LABEL" "$DIR")"
		return 0
	fi

	SCRIPT_LIST=$(find "$DIR" -maxdepth 1 -name 'S??*' -type f 2>/dev/null | sort -r)
	if [ -z "$SCRIPT_LIST" ]; then
		LOG_WARN "$0" 0 "HALT" "$(printf "Skipping %s: no S??* scripts found in %s" "$LABEL" "$DIR")"
		return 0
	fi

	printf '%s\n' "$SCRIPT_LIST" | while IFS= read -r SCRIPT; do
		[ -f "$SCRIPT" ] || continue
		NAME=$(basename "$SCRIPT")
		LOG_INFO "$0" 0 "HALT" "$(printf "Stopping %s (%s)" "$NAME" "$LABEL")"
		case "$SCRIPT" in
			*.sh) RUN_WITH_TIMEOUT 8 3 /bin/sh "$SCRIPT" stop ;;
			*) RUN_WITH_TIMEOUT 8 3 "$SCRIPT" stop ;;
		esac
	done
}

VOLUME_RAMP down

STOP_SERVICES() {
	STOP_DIR "$INIT_DIR" "normal"
	STOP_DIR "$INIT_DIR/async" "async"
}

LOG_INFO "$0" 0 "HALT" "Stopping muX services"
MUXCTL stop

# Avoid hangups from syncthing if it's running.
LOG_INFO "$0" 0 "HALT" "Stopping Syncthing"
TERMINATE_SYNCTHING

LOG_INFO "$0" 0 "HALT" "Stopping web services"
/opt/muos/script/web/service.sh stopall >/dev/null 2>&1

if pgrep '^mux' >/dev/null 2>&1; then
	LOG_INFO "$0" 0 "HALT" "Killing muX modules"
	while :; do
		MUX_PIDS=$(pgrep '^mux') || break
		for MUX_PID in $MUX_PIDS; do
			kill -9 "$MUX_PID" 2>/dev/null
		done

		sleep 0.1
	done
fi

# Check if random theme is enabled and run the random theme script if necessary
if [ "$(GET_VAR "config" "settings/advanced/random_theme")" -eq 1 ] 2>/dev/null; then
	LOG_INFO "$0" 0 "HALT" "Applying random theme"
	/opt/muos/script/package/theme.sh install "?R"
fi

LOG_INFO "$0" 0 "HALT" "Disabling swap"
swapoff -a

# hwclock can hang if the RTC I2C bus is in a bad state apparently
LOG_INFO "$0" 0 "HALT" "Syncing RTC to hardware"
RUN_WITH_TIMEOUT 5 2 hwclock --systohc --utc

LOG_INFO "$0" 0 "HALT" "Resetting used_reset variable"
SET_VAR "system" "used_reset" 0

# Run S??* stop scripts directly in reverse order
LOG_INFO "$0" 0 "HALT" "Stopping system services"
STOP_SERVICES

LOG_SUCCESS "$0" 0 "HALT" "Service stop sequence complete!"

# Send SIGTERM to remaining processes. Wait up to 3s before mopping up
# with SIGKILL, then wait up to 1s more for everything to die.
LOG_INFO "$0" 0 "HALT" "Terminating remaining processes (TERM)"
if ! KILL_AND_WAIT 3 TERM "$@"; then
	LOG_WARN "$0" 0 "HALT" "TERM timeout; escalating to KILL"
	KILL_AND_WAIT 1 KILL "$@"
fi

# Vibrate the device if the user has specifically set it on shutdown
case "$RUMBLE_SETTING" in
	2 | 4 | 6)
		LOG_INFO "$0" 0 "HALT" "Running shutdown rumble"
		RUMBLE "$RUMBLE_DEVICE" 0.3
		;;
esac

# Sync filesystems before handing off. If init subsequent `umount -a -r`
# (from inittab) hangs, or the user hard resets, syncing here reduces the
# likelihood of corrupting any configs, RetroArch autosaves, etc...
LOG_INFO "$0" 0 "HALT" "Syncing writes to disk"
sync

# NOTE: We deliberately do NOT call `umount -ar` here!
#
# Long story short, the `/etc/inittab` declares `::shutdown:/bin/umount -a -r` which
# BusyBox init runs automatically after our handoff to poweroff/reboot. More importantly,
# calling umount -ar from this script can hang in D-state (uninterruptible sleep) if
# any FUSE mount's userspace daemon was killed by the TERM/KILL sweep above the kernel
# waits forever for replies that won't come, and RUN_WITH_TIMEOUT cannot rescue a
# process stuck in D-state because signals are queued but not delivered until the
# it returns from kernel space. https://www.youtube.com/watch?v=rksCTVFtjM4

LOG_INFO "$0" 0 "HALT" "$(printf "Handing off to %s -f" "$ACTION")"
"$ACTION" -f

case "$BOARD_NAME" in
	rg*) echo 0x1801 >"/sys/class/axp/axp_reg" ;;
esac
