#!/bin/sh

. /opt/muos/script/var/func.sh

RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"
RUMBLE_SETTING="$(GET_VAR "config" "settings/advanced/rumble")"

SET_VAR "system" "used_reset" 0

# muOS shutdown/reboot script. This behaves a bit better than BusyBox
# poweroff/reboot commands, which also make some odd choices (e.g., unmounting
# disks before killing processes, so running programs can't save state).

USAGE() {
	printf 'Usage: %s {poweroff|reboot}\n' "$0" >&2
	exit 1
}

# We pass our arguments along to halt_internal.sh, which forwards extra args to
# killall5. In particular, we can append `-o PID` arguments to avoid killing
# specific processes too early in the sequence.
[ "$#" -eq 1 ] || USAGE

case "$1" in
	poweroff | reboot) ;;
	*) USAGE ;;
esac

# Omit various programs from the termination process.
# FUSE filesystems (e.g., exFAT) would unmount in parallel with other programs
# exiting, preventing them from writing state to the SD card during cleanup.
for OMIT_PID in $(pidof /opt/muos/frontend/muterm /opt/muos/frontend/muxsplash /sbin/mount.exfat-fuse 2>/dev/null); do
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

# Avoid hangups from syncthing if it's running.
if [ "$(GET_VAR "config" "web/syncthing")" -eq 1 ]; then
	LOG_INFO "$0" 0 "HALT" "Shutdown Syncthing gracefully"
	SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' /run/muos/storage/syncthing/config.xml)
	CURL_OUTPUT=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-API-Key: $SYNCTHING_API" "http://localhost:7070/rest/system/shutdown")
	if [ "$CURL_OUTPUT" -eq 200 ]; then
		LOG_INFO "$0" 0 "HALT" "Syncthing shutdown request sent successfully."
	fi
fi

# Muting audio so we don't get any of those nasty clicks from the speaker.
wpctl set-mute @DEFAULT_AUDIO_SINK@ "1"

# Kill the lid switch process if it exists.
if pgrep lid.sh >/dev/null 2>&1; then
	LOG_INFO "$0" 0 "HALT" "Killing lid switch detection"
	killall -q lid.sh
fi

LOG_INFO "$0" 0 "HALT" "Killing muX modules"
while :; do
	PIDS=$(ps -e | grep '[m]ux' | grep -v 'muxsplash' | awk '{ print $1 }')
	[ -z "$PIDS" ] && break

	for PID in $PIDS; do
		kill -9 "$PID" 2>/dev/null
	done

	/opt/muos/bin/toybox sleep 0.25
done

# Cleanly unmount filesystems to avoid fsck/chkdsk errors.
LOG_INFO "$0" 0 "HALT" "Stopping union mounts"
/opt/muos/script/mount/union.sh stop

# Check if random theme is enabled and run the random theme script if necessary
#if [ "$(sed -n '/^\[settings\.advanced\]/,/^\[/{ /^random_theme[ ]*=[ ]*/{ s/^[^=]*=[ ]*//p }}' /opt/muos/config/config.ini)" -eq 1 ] 2>/dev/null; then
#	printf 'Random theme is enabled. Changing to a random theme...\n'
#	/opt/muos/script/package/theme.sh install "?R"
#fi

LOG_INFO "$0" 0 "HALT" "Disabling any swapfile mounts"
swapoff -a

# Unloading kernel modules.
LOG_INFO "$0" 0 "HALT" "Unloading kernel modules"
/opt/muos/device/script/module.sh unload

# Stop system services. If shutdown scripts are still running after
# 10s, SIGTERM them, then wait 5s more before resorting to SIGKILL.
LOG_INFO "$0" 0 "HALT" "Stopping system services"
RUN_WITH_TIMEOUT 10 5 'shutdown scripts' /etc/init.d/rcK

# Send SIGTERM to remaining processes. Wait up to 10s before mopping up
# with SIGKILL, then wait up to 1s more for everything to die.
LOG_INFO "$0" 0 "HALT" "Terminating remaining processes"
if ! KILL_AND_WAIT 10 TERM "$@"; then
	KILL_AND_WAIT 1 KILL "$@"
fi

# Vibrate the device if the user has specifically set it on shutdown
case "$RUMBLE_SETTING" in
	2 | 4 | 6)
		LOG_INFO "$0" 0 "HALT" "Running shutdown rumble"
		RUMBLE "$RUMBLE_DEVICE" 0.3
		;;
esac

# Sync filesystems before beginning the standard halt sequence. If a
# subsequent step hangs (or the user hard resets), syncing here reduces
# the likelihood of corrupting muOS configs, RetroArch autosaves, etc.
LOG_INFO "$0" 0 "HALT" "Syncing writes to disk..."
sync

LOG_INFO "$0" 0 "HALT" "Unmounting storage devices..."
sync && umount -ar
exec "$1" -f
