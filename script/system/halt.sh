#!/bin/sh

# muOS shutdown/reboot script. This behaves a bit better than BusyBox
# poweroff/reboot commands, which also make some odd choices (e.g., unmounting
# disks before killing processes, so running programs can't save state).

USAGE() {
	printf 'Usage: %s {halt|poweroff|reboot}\n' "$0" >&2
	exit 1
}

# We pass our arguments along to halt_internal.sh, which forwards extra args to
# killall5. In particular, we can append `-o PID` arguments to avoid killing
# specific processes too early in the sequence.
[ "$#" -eq 1 ] || USAGE

case "$1" in
	halt | poweroff | reboot) ;;
	*) USAGE ;;
esac

# Omit various programs from the termination process.
# FUSE filesystems (e.g., exFAT) would unmount in parallel with other programs
# exiting, preventing them from writing state to the SD card during cleanup.
for OMIT_PID in $(pidof /opt/muos/extra/muterm /opt/muos/extra/muxsplash /sbin/mount.exfat-fuse 2>/dev/null); do
	set -- "$@" -o "$OMIT_PID"
done

# We kill processes using killall5, which sends signals to processes outside
# the current session. We might miss killing some processes since we don't know
# anything about the session we're started in.
#
# We address this by wrapping the actual shutdown sequence in a setsid command,
# ensuring we invoke killall5 from a new, empty session.
#
# Use -f to always fork a new process, even if it would possible for the
# current process to become a session leader directly. This prevents our parent
# process from "helpfully" trying to kill us when it terminates.
#
# Use -w to wait for halt_internal.sh to terminate so we can return an
# appropriate exit status if the shutdown fails partway through.
#
# Runs an external command and waits for it to finish or a timeout to expire.
# If the timeout expires, sends SIGTERM to the program and waits a bit more
# before sending SIGKILL if it still hasn't exited.
#
# Usage: RUN_WITH_TIMEOUT TERM_SEC KILL_SEC DESCRIPTION CMD [ARG]...
RUN_WITH_TIMEOUT() {
	TERM_SEC=$1
	KILL_SEC=$2
	DESCRIPTION=$3
	shift 3

	printf 'Running %s...\n' "$DESCRIPTION"

	(
		"$@" &
		CMD_PID=$!
		(
			/opt/muos/bin/toybox sleep "$TERM_SEC"
			kill -TERM "$CMD_PID" 2>/dev/null
		) &
		TERM_PID=$!
		(
			/opt/muos/bin/toybox sleep $((TERM_SEC + KILL_SEC))
			kill -KILL "$CMD_PID" 2>/dev/null
		) &
		KILL_PID=$!

		wait "$CMD_PID"
		STATUS=$?

		kill -0 "$TERM_PID" 2>/dev/null && kill "$TERM_PID"
		kill -0 "$KILL_PID" 2>/dev/null && kill "$KILL_PID"

		if [ "$STATUS" -gt 128 ]; then
			printf 'Killed %s after timeout\n' "$DESCRIPTION"
		fi
		exit "$STATUS"
	)
	return $?
}

# Sends the specified termination signal to every process outside the current
# session, then waits the specified number of seconds for those processes to
# exit. Rechecks every 250ms to see if they've all died yet.
#
# Usage: KILL_AND_WAIT TIMEOUT_SEC SIGNAL [-o OMIT_PID]...
KILL_AND_WAIT() {
	TIMEOUT_SEC=$1
	SIGNAL=$2
	shift 2

	printf 'Sending SIG%s to processes...\n' "$SIGNAL"
	killall5 "-$SIGNAL" "$@"

	printf 'Waiting for processes to terminate: '
	i=0
	MAX=$((TIMEOUT_SEC * 4))

	while [ "$i" -lt "$MAX" ]; do
		PROCS=$(FIND_PROCS "$@")
		[ -z "$PROCS" ] && {
			printf 'done\n'
			return 0
		}
		/opt/muos/bin/toybox sleep 0.25
		i=$((i + 1))
	done

	printf 'timed out\nStill running: %s\n' "$PROCS"
	return 1
}

# Prints a space-separated list of running process command names using the same
# criteria as killall5. Returns success if at least one such process is found.
#
# Usage: FIND_PROCS [-o OMIT_PID]...
FIND_PROCS() {
	CURRENT_SID=$(cut -d ' ' -f 6 /proc/self/stat)
	OMIT_PIDS=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-o)
				shift
				OMIT_PIDS="$OMIT_PIDS $1"
				shift
				;;
			*) shift ;;
		esac
	done

	FOUND=""
	ps -eo pid=,sid=,comm= | while read -r PID SID COMM; do
		[ "$PID" -eq 1 ] && continue
		[ "$SID" -eq 0 ] && continue
		[ "$SID" -eq "$CURRENT_SID" ] && continue

		for O in $OMIT_PIDS; do
			[ "$PID" -eq "$O" ] && continue 2
		done

		# shellcheck disable=SC2030
		FOUND="${FOUND:+$FOUND }$COMM"
	done

	# shellcheck disable=SC2031
	[ -n "$FOUND" ] && {
		echo "$FOUND"
		return 0
	}

	return 1
}

HALT_CMD=$1
shift

{
	# Unloading kernel modules.
	printf 'Unloading kernel modules...\n'
	/opt/muos/device/current/script/module.sh unload

	# Cleanly unmount filesystems to avoid fsck/chkdsk errors.
	printf 'Stopping union mounts...\n'
	/opt/muos/script/mount/union.sh stop

	# Kill the lid switch process if it exists
	pgrep lid.sh >/dev/null 2>&1 && killall -q lid.sh

	# We have to ensure we save all of the runtime variables to disk before
	# we shutdown or reboot the system as they are stored in tmpfs.
	printf 'Saving device variables...\n'
	/opt/muos/script/var/init.sh save device

	printf 'Saving global variables...\n'
	/opt/muos/script/var/init.sh save global

	# Check if random theme is enabled and run the random theme script if necessary
	#if [ "$(sed -n '/^\[settings\.advanced\]/,/^\[/{ /^random_theme[ ]*=[ ]*/{ s/^[^=]*=[ ]*//p }}' /opt/muos/config/config.ini)" -eq 1 ] 2>/dev/null; then
	#	printf 'Random theme is enabled. Changing to a random theme...\n'
	#	/opt/muos/script/package/theme.sh install "?R"
	#fi

	# Sync filesystems before beginning the standard halt sequence. If a
	# subsequent step hangs (or the user hard resets), syncing here reduces
	# the likelihood of corrupting muOS configs, RetroArch autosaves, etc.
	printf 'Syncing writes to disk...\n'
	sync

	# Stop system services. If shutdown scripts are still running after
	# 10s, SIGTERM them, then wait 5s more before resorting to SIGKILL.
	RUN_WITH_TIMEOUT 10 5 'shutdown scripts' /etc/init.d/rcK

	# Send SIGTERM to remaining processes. Wait up to 10s before mopping up
	# with SIGKILL, then wait up to 1s more for everything to die.
	if ! KILL_AND_WAIT 10 TERM "$@"; then
		KILL_AND_WAIT 1 KILL "$@"
	fi

	# Log output for debugging, but close the log file before we sync and
	# unmount to ensure it's written and avoid keeping the filesystem busy.
	printf 'Closing log file...\n'
} 2>&1 | awk '{ cmd="date +\"%Y-%m-%d %H:%M:%S\""; cmd | getline t; close(cmd); print t, $0 }' >>/opt/muos/halt.log

# Sync filesystems before unmounting them. (This should be unnecessary, but
# sysvinit does it, and the cached writes need to be flushed at some point.)
printf 'Syncing writes to disk...\n'
sync

# Disable swap. (It's not enabled by default, but just in case.)
printf 'Disabling swap...\n'
swapoff -a

printf 'Unmounting filesystems...\n'
umount -ar

printf 'Going down via %s...\n' "$HALT_CMD"

# Final sync and remount read-only before shutdown
sync
echo u >/proc/sysrq-trigger

case "$HALT_CMD" in
	halt | poweroff) echo o >/proc/sysrq-trigger ;;
	reboot) echo b >/proc/sysrq-trigger ;;
esac

# If that didn't work, panic the kernel ^_^
echo 'Sysrq shutdown failed, forcing kernel panic...'
echo c >/proc/sysrq-trigger
