#!/bin/sh

# muOS shutdown/reboot script. This behaves a bit better than BusyBox
# poweroff/reboot commands, which also make some odd choices (e.g., unmounting
# disks before killing processes, so running programs can't save state).

USAGE () {
	printf 'Usage: %s {halt|poweroff|reboot}\n' "$0" >&2
	exit 1
}

# We pass our arguments along to halt_internal.sh, which forwards extra args to
# killall5. In particular, we can append `-o PID` arguments to avoid killing
# specific processes too early in the sequence.
[ "$#" -eq 1 ] || USAGE

case "$1" in
	halt|poweroff|reboot) ;;
	*) USAGE ;;
esac

# With verbose messages enabled, we're launched inside fbpad. Omit it from the
# termination process so console output remains visible.
if [ "$(readlink "/proc/$PPID/exe")" = /opt/muos/bin/fbpad ]; then
	set -- "$@" -o "$PPID"
fi

# Omit muxsplash from the termination process to ensure shutdown splash shows.
for OMIT_PID in $(pidof /opt/muos/extra/muxsplash); do
	set -- "$@" -o "$OMIT_PID"
done

# Omit FUSE mount binaries from the termination process. Otherwise, FUSE
# filesystems (e.g., exFAT) would unmount in parallel with other programs
# exiting, preventing them from writing state to the SD card during cleanup.
for OMIT_PID in $(pidof /sbin/mount.exfat-fuse); do
	set -- "$@" -o "$OMIT_PID"
done

# Our shutdown sequence kills processes using killall5, which sends signals to
# every process except those in the current session. This means by default, we
# might miss killing some processes (e.g., background jobs in the same shell as
# halt.sh is invoked).
#
# We address this by wrapping the actual shutdown sequence in a setsid command,
# ensuring we invoke killall5 from a new (and otherwise empty) session.
#
# Use -f to always fork a new process, even if it would possible for the
# current process to become a session leader directly. This ensures
# halt_internal.sh always gets a new PID, which prevents our parent process
# from "helpfully" trying to kill us when it terminates.
#
# Use -w to wait for halt_internal.sh to terminate. On a successful halt, that
# doesn't really matter, but it allows us to return an appropriate exit status
# if the shutdown fails partway through.
exec setsid -fw /opt/muos/script/system/halt_internal.sh "$@"
