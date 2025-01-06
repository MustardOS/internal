#!/bin/sh

# Runs an external command and waits for it to finish or a timeout to expire.
# If the timeout expires, sends SIGTERM to the program and waits a bit more
# before sending SIGKILL if it still hasn't exited.
#
# Usage: RUN_WITH_TIMEOUT TERM_SEC KILL_SEC DESCRIPTION CMD [ARG]...
RUN_WITH_TIMEOUT() {
	local TERM_SEC="$1" KILL_SEC="$2" DESCRIPTION="$3"
	shift 3

	printf 'Running %s...\n' "$DESCRIPTION"
	timeout -k "$KILL_SEC" "$TERM_SEC" "$@"

	local EXIT_STATUS="$?"
	if [ "$EXIT_STATUS" -gt 128 ]; then
		# Command exited due to signal.
		printf 'Killed %s after timeout\n' "$DESCRIPTION"
	fi
	return "$EXIT_STATUS"
}

# Sends the specified termination signal to every process outside the current
# session, then waits the specified number of seconds for those processes to
# exit. Rechecks every 250ms to see if they've all died yet.
#
# Usage: KILL_AND_WAIT TIMEOUT_SEC SIGNAL [-o OMIT_PID]...
KILL_AND_WAIT() {
	local TIMEOUT_SEC="$1" SIGNAL="$2" PROCS
	shift 2

	printf 'Sending SIG%s to processes...\n' "$SIGNAL"
	killall5 "-$SIGNAL" "$@"

	printf 'Waiting for processes to terminate: '
	for _ in $(seq "$((TIMEOUT_SEC * 100 / 25))"); do
		# Minimum 250ms delay for things to settle a bit.
		sleep .25
		if ! PROCS="$(FIND_PROCS "$@")"; then
			printf 'done\n'
			return 0
		fi
	done
	printf 'timed out\nStill running: %s\n' "$PROCS"
	return 1
}

# Prints a space-separated list of running process command names using the same
# criteria as killall5. Returns success if at least one such process is found.
#
# Usage: FIND_PROCS [-o OMIT_PID]...
FIND_PROCS() {
	local EXIT_STATUS=1 PID SID COMM
	while read -r PID SID COMM; do
		# Skip init (PID 1), kernel threads (SID 0), and this session.
		if [ "$PID" -eq 1 ] || [ "$SID" -eq 0 ] || [ "$SID" -eq "$CURRENT_SID" ]; then
			continue
		fi
		# Skip PIDs the caller tells us to. List should be short, so
		# linear search is okay. (killall5 does the same internally.)
		local OPT OPTARG OPTIND=1
		while getopts o: OPT; do
			if [ "$OPT" = o ] && [ "$PID" -eq "$OPTARG" ]; then
				continue 2
			fi
		done
		# Fonud a running process matching our criteria.
		if [ "$EXIT_STATUS" -ne 0 ]; then
			EXIT_STATUS=0
		else
			printf ' '
		fi
		printf '%s' "$COMM"
	done < <(ps -o pid=,sid=,comm=)
	return "$EXIT_STATUS"
}

# Sanity check that SID = PID. (See note on setsid in halt.sh for rationale.)
CURRENT_SID="$(cut -d ' ' -f 6 /proc/self/stat)"
if [ "$CURRENT_SID" -ne "$$" ]; then
	printf 'Not a session leader (run halt.sh, not halt_internal.sh)\n' >&2
	exit 1
fi

# Any additional args will be passed to killall5 directly, allowing the caller
# to specify `-o PID` and omit certain processes from early termination.
if [ "$#" -le 1 ]; then
	printf 'Wrong number of arguments (run halt.sh, not halt_internal.sh)\n' >&2
	exit 1
fi

HALT_CMD="$1"
shift 1

{
	# We have to ensure we save all of the runtime variables to disk before
	# we shutdown or reboot the system as they are stored in tmpfs.
	printf 'Saving device variables...\n'
	/opt/muos/script/var/init/device.sh save
	printf 'Saving global variables...\n'
	/opt/muos/script/var/init/global.sh save

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
} 2>&1 | tee >(ts '%Y-%m-%d %H:%M:%S' >>/opt/muos/halt.log)

# Sync filesystems before unmounting them. (This should be unnecessary, but
# sysvinit does it, and the cached writes need to be flushed at some point.)
printf 'Syncing writes to disk...\n'
sync

# Disable swap. (It's not enabled by default, but just in case.)
printf 'Disabling swap...\n'
swapoff -a

# Cleanly unmount filesystems to avoid fsck/chkdsk errors.
printf 'Unmounting filesystems...\n'
/opt/muos/script/mount/union.sh stop
umount -ar

# Actually halt/shut down/reboot the system. The -f arg makes the command
# directly run sync/reboot syscalls, not signal init to perform the halt itself.
printf 'Going down for %s...\n' "$HALT_CMD"
exec "$HALT_CMD" -f
