#!/bin/sh

# Waits 5 seconds for processes to die. The `killall5 -CONT` trick is inspired
# by various old sysvinit scripts as a harmless way to check if any processes
# we tried to kill are still alive.
#
# Any arguments are passed along to killall5. (Use `-o PID` args to omit
# certain processes from the existence check.)
WAIT_FOR_DEATH () {
	printf 'Waiting for processes to terminate: '
	for _ in $(seq 10); do
		# Note we sleep *before* the first check, so we always delay
		# 500ms. This may not be strictly necessary, but seems prudent
		# given the weird timing issues with shutdown.
		sleep .5
		# If killall5 didn't find any processes to signal, they must
		# all have terminated already, and we can stop waiting.
		if ! killall5 -CONT "$@"; then
			printf 'done\n'
			return
		fi
	done
	printf 'timed out\n'
}

# Sanity check that SID = PID. (See note on setsid in halt.sh for rationale.)
if [ "$(cut -d ' ' -f 6 /proc/self/stat)" -ne "$$" ]; then
	printf 'Not a session leader (run halt.sh, not halt_internal.sh)\n' >&2
	exit 1
fi

# Sanity check required parameters. Any additional args will be passed to
# killall5 directly, allowing the caller to specify `-o PID` and safeguard
# certain processes (e.g., FUSE mounts) from our initial termination pass.
if [ "$#" -le 1 ]; then
	printf 'Wrong number of arguments (run halt.sh, not halt_internal.sh)\n' >&2
	exit 1
fi

HALT_CMD="$1"
shift 1

# Stop system services.
printf 'Running shutdown scripts...\n'
/etc/init.d/rcK

# Terminate other processes, giving them some time to clean up.
printf 'Sending SIGTERM to processes...\n'
killall5 -TERM "$@"
WAIT_FOR_DEATH "$@"

printf 'Sending SIGKILL to processes...\n'
killall5 -KILL "$@"
WAIT_FOR_DEATH "$@"

# Disable swap. (It's not enabled by default, but just in case.)
printf 'Disabling swap...\n'
swapoff -a

# Cleanly unmount filesystems to avoid fsck/chkdsk errors.
printf 'Unmounting filesystems...\n'
umount -arv

# Actually halt/shut down/reboot the system. Note the -f so the halt command
# only calls sync and reboot under the hood, rather than signaling init to
# start its own buggy shutdown sequence.
printf 'Going down for %s...\n' "$HALT_CMD"
"$HALT_CMD" -f
