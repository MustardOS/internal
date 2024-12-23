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

# With verbose messages enabled, we're launched inside fbpad. Omit it from the
# termination process so console output remains visible.
if [ "$(readlink "/proc/$PPID/exe")" = /opt/muos/bin/fbpad ]; then
	set -- "$@" -o "$PPID"
fi

# Omit muxsplash from the termination process to ensure shutdown splash shows.
#
# Omit FUSE mount binaries from the termination process. Otherwise, FUSE
# filesystems (e.g., exFAT) would unmount in parallel with other programs
# exiting, preventing them from writing state to the SD card during cleanup.
for OMIT_PID in $(pidof /opt/muos/extra/muxsplash /sbin/mount.exfat-fuse); do
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
exec setsid -fw /opt/muos/script/system/halt_internal.sh "$@"
