#!/bin/sh

# muOS shutdown/reboot script. This behaves a bit better than BusyBox
# poweroff/reboot commands, which tend to hang (unknown timing issue?), and
# which also make some odd choices (e.g., unmounting disks before sending
# SIGTERM to processes, so running programs can't save state to disk.)

# We pass our arguments along to halt_internal.sh, and we also build a list of
# additional arguments (`set -- "$@" ARGS...`) that halt_internal.sh forwards
# further to killall5. Specifically, we use `-o PID` params to tell killall5
# not to kill certain processes too early in the sequence.
case "$1" in
	halt|poweroff|reboot) ;;
	*)
		printf 'Usage: %s {halt|poweroff|reboot}\n' "$0" >&2
		exit 1
		;;
esac

# As a debugging aid, check if our parent process is fbpad so we can avoid
# killing it. This gives us an easy way to see full script output up to the
# final halt command.
if [ "$(readlink "/proc/$PPID/exe")" = /opt/muos/bin/fbpad ]; then
	set -- "$@" -o "$PPID"
fi

# exFAT mounts are FUSE filesystems, and they unmount when their usermode FUSE
# processes are terminated. By default, exFAT partitions would unmount in
# parallel with cleanup that other programs do on SIGTERM, which could prevent
# programs that write state to the SD cards from doing so on exit.
#
# To avoid that, we omit FUSE mount binaries from our termination process.
# Instead, the FUSE filesystems are unmounted by `umount -a` just like the
# kernel filesystems.
for FUSE_PID in $(pidof /sbin/mount.exfat-fuse); do
	set -- "$@" -o "$FUSE_PID"
done

# Our shutdown sequence kills processes using killall5, which sends signals to
# every process except those in the current session. This means by default, we
# might miss killing some processes (e.g., background jobs in the same shell as
# halt.sh is invoked.)
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
