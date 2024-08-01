#!/bin/sh

case "$1" in
	halt|poweroff|reboot)
		HALT_CMD="$1"
		;;
	*)
		printf 'Usage: %s {halt|poweroff|reboot}\n' "$0" >&2
		exit 1
		;;
esac

# As a debugging aid, check if our parent process is fbpad so we can avoid
# killing it. This gives us an easy way to see full script output up to the
# final halt command.
if [ "$(readlink "/proc/$PPID/exe")" = /opt/muos/bin/fbpad ]; then
	OMIT_PID="$PPID"
else
	OMIT_PID=
fi

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
exec setsid -fw /opt/muos/script/system/halt_internal.sh "$HALT_CMD" "$OMIT_PID"
