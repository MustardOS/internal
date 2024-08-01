#!/bin/sh

# Wraps killall5 and automatically omits the specified PID (if any).
KILL_PROCS () {
	if [ -n "$OMIT_PID" ]; then
		killall5 "$@" -o "$OMIT_PID"
	else
		killall5 "$@"
	fi
}

# Waits 5 seconds for processes we SIGTERM'd to die. The `killall5 -CONT` trick
# is inspired by various old sysvinit scripts as a harmless way to check if any
# processes we targeted with SIGTERM are still alive.
WAIT_FOR_DEATH () {
	printf 'Waiting for processes to terminate: '
	for _ in $(seq 5); do
		sleep 1
		# If killall5 didn't find any processes to signal, they must
		# all have terminated already, and we can stop waiting.
		if ! KILL_PROCS -CONT; then
			printf 'done\n'
			return
		fi
	done
	# After waiting politely a few seconds, let SIGKILL take care of 'em.
	printf 'timed out\n'
}

# Sanity check parameters.
if [ "$#" -ne 2 ]; then
	printf 'Wrong number of arguments (run halt.sh, not halt_internal.sh)\n' >&2
	exit 1
fi

HALT_CMD="$1"
OMIT_PID="$2"

# Sanity check that SID = PID. (See note on setsid in halt.sh for rationale.)
if [ "$(cut -d ' ' -f 6 /proc/self/stat)" -ne "$$" ]; then
	printf 'Not a session leader (run halt.sh, not halt_internal.sh)\n' >&2
	exit 1
fi

# Stop system services.
printf 'Stopping init scripts...\n'
/etc/init.d/rcK

# Terminate other processes before halting. This is essentially what init
# should do for us, but for some reason, BusyBox shutdown often hangs. This
# doesn't seem to. (Why? Not sure, but it may be because we wait for processes
# to terminate, and don't unmount till they're gone.)
printf 'Sending SIGTERM to processes...\n'
KILL_PROCS -TERM
WAIT_FOR_DEATH

printf 'Sending SIGKILL to processes...\n'
KILL_PROCS -KILL

# Disable swap (we don't actually have any, but it's standard in shutdown
# sequences) and cleanly unmount filesystems to avoid fsck/chkdsk errors.
printf 'Disabling swap...\n'
swapoff -a

printf 'Unmounting filesystems...\n'
umount -ar

# Actually halt/shut down/reboot the system. Note the -f so the halt command
# only calls sync and reboot under the hood, rather than signaling init to
# start its own buggy shutdown sequence.
printf 'Going down for %s...\n' "$HALT_CMD"
"$HALT_CMD" -f
