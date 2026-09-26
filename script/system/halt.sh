#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")
RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"
RUMBLE_SETTING="$(GET_VAR "config" "settings/advanced/rumble")"

INIT_DIR="/opt/muos/script/init"

USAGE() {
	printf 'Usage: %s {poweroff|reboot} [factory]\n' "$0" >&2
	exit 1
}

case "$#" in
	1 | 2) ;;
	*) USAGE ;;
esac
case "$1" in
	poweroff | reboot) ;;
	*) USAGE ;;
esac

case "${2:-}" in
	"" | factory) ;;
	*) USAGE ;;
esac

ACTION=$1
HALT_MODE=${2:-normal}

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
	CMD_POLL=0
	CMD_POLL_MAX=$((TERM_SEC * 10))

	while [ -r "/proc/$CMD_PID/stat" ] && [ "$CMD_POLL" -lt "$CMD_POLL_MAX" ]; do
		read -r _ _ CMD_STATE _ <"/proc/$CMD_PID/stat" 2>/dev/null || break
		[ "$CMD_STATE" = Z ] && break
		sleep 0.1
		CMD_POLL=$((CMD_POLL + 1))
	done

	if [ -r "/proc/$CMD_PID/stat" ]; then
		read -r _ _ CMD_STATE _ <"/proc/$CMD_PID/stat" 2>/dev/null || CMD_STATE=Z
		[ "$CMD_STATE" = Z ] || kill -TERM -"$CMD_PID" 2>/dev/null
	fi

	CMD_POLL=0
	CMD_POLL_MAX=$((KILL_SEC * 10))
	while [ -r "/proc/$CMD_PID/stat" ] && [ "$CMD_POLL" -lt "$CMD_POLL_MAX" ]; do
		read -r _ _ CMD_STATE _ <"/proc/$CMD_PID/stat" 2>/dev/null || break
		[ "$CMD_STATE" = Z ] && break
		sleep 0.1
		CMD_POLL=$((CMD_POLL + 1))
	done

	if [ -r "/proc/$CMD_PID/stat" ]; then
		read -r _ _ CMD_STATE _ <"/proc/$CMD_PID/stat" 2>/dev/null || CMD_STATE=Z
		if [ "$CMD_STATE" != Z ]; then
			kill -KILL -"$CMD_PID" 2>/dev/null
			return 124
		fi
	fi

	wait "$CMD_PID"
}

# Iterate one init directory's S??* scripts in reverse order,
# invoking each with `stop` under its own per-script timeout.
#
# Usage: STOP_DIR PATH LABEL
STOP_DIR() {
	DIR=$1
	LABEL=$2
	SKIP=${3:-}

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
		case " $SKIP " in *" $NAME "*) continue ;; esac
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
	[ "$HALT_MODE" = factory ] && return 0
	STOP_DIR "$INIT_DIR/async" "async" "S06mount.sh"
	RUN_WITH_TIMEOUT 8 3 /bin/sh "$INIT_DIR/async/S06mount.sh" stop
}

LOG_INFO "$0" 0 "HALT" "Running indicator LED shutdown sweep"
/opt/muos/script/device/led.sh shutdown

case "$ACTION" in
	poweroff | shutdown) SPLASH_ROLE=shutdown ;;
	*) SPLASH_ROLE=$ACTION ;;
esac

LOG_INFO "$0" 0 "HALT" "Stopping muX services"
MESSAGE stop
MUXCTL stop

if pgrep '^mux' >/dev/null 2>&1; then
	LOG_INFO "$0" 0 "HALT" "Killing remaining muX modules"
	MUX_WAIT=0
	while [ "$MUX_WAIT" -lt 30 ]; do
		MUX_PIDS=$(pgrep '^mux') || break
		for MUX_PID in $MUX_PIDS; do
			kill -9 "$MUX_PID" 2>/dev/null
		done

		sleep 0.1
		MUX_WAIT=$((MUX_WAIT + 1))
	done
	pgrep '^mux' >/dev/null 2>&1 && LOG_WARN "$0" 0 "HALT" "muX processes remained after three seconds"
fi

SPLASH_DIR="/tmp/mustardos"
SPLASH_READY="$SPLASH_DIR/musplash.ready"
mkdir -p "$SPLASH_DIR"
chmod 700 "$SPLASH_DIR"
rm -f "$SPLASH_READY"

if [ "$BOARD_NAME" = "rk-g350-v" ]; then
	G350_DISPLAY_HOLD="/lib/modules/$(uname -r)/extra/disphold.ko"
	if grep -q '^disphold ' /proc/modules 2>/dev/null; then
		LOG_INFO "$0" 0 "HALT" "G350 display shutdown hold already active"
	elif [ -r "$G350_DISPLAY_HOLD" ] && insmod "$G350_DISPLAY_HOLD"; then
		LOG_INFO "$0" 0 "HALT" "G350 display shutdown hold active"
	else
		LOG_WARN "$0" 0 "HALT" "G350 display shutdown hold unavailable"
	fi
fi

LOG_INFO "$0" 0 "HALT" "Drawing splash"
(SHOW_SPLASH "$SPLASH_ROLE" "$SPLASH_READY" 1) &
SPLASH_PID=$!
SPLASH_POLL=0
SPLASH_GONE=0
while [ "$SPLASH_POLL" -lt 30 ] && [ ! -f "$SPLASH_READY" ]; do
	SPLASH_STATE=
	[ -r "/proc/$SPLASH_PID/stat" ] && read -r _ _ SPLASH_STATE _ <"/proc/$SPLASH_PID/stat" 2>/dev/null
	if [ -z "$SPLASH_STATE" ] || [ "$SPLASH_STATE" = Z ]; then
		SPLASH_GONE=1
		break
	fi
	sleep 0.1
	SPLASH_POLL=$((SPLASH_POLL + 1))
done

if [ -f "$SPLASH_READY" ]; then
	LOG_INFO "$0" 0 "HALT" "Splash ready"
elif [ "$SPLASH_GONE" -eq 1 ]; then
	# Nothing was drawn, so whatever the frontend left behind is still on screen
	LOG_WARN "$0" 0 "HALT" "$(printf "Splash stopped before drawing anything after %s00ms" "$SPLASH_POLL")"
else
	LOG_WARN "$0" 0 "HALT" "Splash did not become ready within three seconds"
	kill -TERM "$SPLASH_PID" 2>/dev/null
	sleep 0.1
	kill -KILL "$SPLASH_PID" 2>/dev/null
fi

SPLASH_STATE=
[ -r "/proc/$SPLASH_PID/stat" ] && read -r _ _ SPLASH_STATE _ <"/proc/$SPLASH_PID/stat" 2>/dev/null
if [ -z "$SPLASH_STATE" ] || [ "$SPLASH_STATE" = Z ]; then
	wait "$SPLASH_PID" 2>/dev/null
fi
rm -f "$SPLASH_READY"

LOG_INFO "$0" 0 "HALT" "Stopping web services"
RUN_WITH_TIMEOUT 5 1 /opt/muos/script/web/service.sh stopall >/dev/null 2>&1

# Check if random theme is enabled and run the random theme script if necessary
if [ "$(GET_VAR "config" "settings/advanced/random_theme")" -eq 1 ] 2>/dev/null; then
	LOG_INFO "$0" 0 "HALT" "Applying random theme"
	RUN_WITH_TIMEOUT 10 2 /opt/muos/script/package/theme.sh install "?R"
fi

LOG_INFO "$0" 0 "HALT" "Disabling swap"
RUN_WITH_TIMEOUT 5 1 swapoff -a || LOG_WARN "$0" 0 "HALT" "Swap disable did not complete"

# hwclock can hang if the RTC I2C bus is in a bad state apparently
LOG_INFO "$0" 0 "HALT" "Syncing RTC to hardware"
RUN_WITH_TIMEOUT 5 2 hwclock --systohc --utc

LOG_INFO "$0" 0 "HALT" "Resetting used_reset variable"
SET_VAR "system" "used_reset" 0

# Run S??* stop scripts directly in reverse order
LOG_INFO "$0" 0 "HALT" "Stopping system services"
MUOS_HALT=1
export MUOS_HALT
RUN_WITH_TIMEOUT 2 1 /bin/sh "$INIT_DIR/async/S05device.sh" stop
STOP_SERVICES

LOG_SUCCESS "$0" 0 "HALT" "Service stop sequence complete!"

LOG_INFO "$0" 0 "HALT" "Flushing config cache"
if [ -x "$MUOS_VAR_BIN" ]; then
	RUN_WITH_TIMEOUT 3 1 "$MUOS_VAR_BIN" flush || LOG_WARN "$0" 0 "HALT" "Config cache flush reported failed writes"
fi

# Vibrate the device if the user has specifically set it on shutdown
case "$RUMBLE_SETTING" in
	2 | 4 | 6)
		LOG_INFO "$0" 0 "HALT" "Running shutdown rumble"
		RUMBLE "$RUMBLE_DEVICE" 0.3
		;;
esac

# Sync filesystems before handing off. If the user hard resets, or anything
# below cannot finish, syncing here reduces the likelihood of corrupting any
# configs, RetroArch autosaves, etc...
LOG_INFO "$0" 0 "HALT" "Syncing writes to disk"
RUN_WITH_TIMEOUT 8 2 sync || LOG_WARN "$0" 0 "HALT" "Disk sync did not complete"

(
	trap '' HUP INT TERM
	sleep 30
	"$ACTION" -f
) &

# NOTE: We deliberately do NOT call `umount -ar` here!
#
# Calling umount -ar from this script can hang in D-state (uninterruptible sleep) if
# a FUSE mount's userspace daemon stops responding. RUN_WITH_TIMEOUT cannot rescue a
# process stuck in D-state because signals are queued but not delivered until it
# returns from kernel space. https://www.youtube.com/watch?v=rksCTVFtjM4
#
# The `/etc/inittab` does declare `::shutdown:/bin/umount -a -r`, but that never
# runs: BusyBox poweroff and reboot with -f bypass init and call the reboot
# syscall straight out, so nothing marks the filesystems clean.  Left like that
# every following boot replays the ext4 journal before it can even start, which
# is both slow and a standing risk to whatever was still in flight.
#
# So the block backed filesystems are remounted read only here instead.  FUSE is
# skipped for the D-state reason above, and a filesystem that refuses because
# something still holds a write handle simply stays as it was, which is no
# worse than not trying I suppose!
REMOUNT_READ_ONLY() {
	MOUNT_LIST=$(awk '
		$1 ~ /^\/dev\// && $3 ~ /^(ext2|ext3|ext4|vfat|msdos)$/ && $4 !~ /^ro(,|$)/ {
			if (!($1 in target) || length($2) < length(target[$1])) target[$1] = $2
		}
		END {
			for (device in target) if (target[device] != "/") print target[device]
			for (device in target) if (target[device] == "/") print target[device]
		}
	' /proc/mounts)
	[ -n "$MOUNT_LIST" ] || return 0

	for MOUNT_POINT in $MOUNT_LIST; do
		if RUN_WITH_TIMEOUT 3 1 mount -o remount,ro "$MOUNT_POINT"; then
			LOG_INFO "$0" 0 "HALT" "$(printf "Remounted %s read only" "$MOUNT_POINT")"
		else
			LOG_WARN "$0" 0 "HALT" "$(printf "Could not remount %s read only, still in use" "$MOUNT_POINT")"
		fi
	done
}

LOG_INFO "$0" 0 "HALT" "Remounting filesystems read only"
REMOUNT_READ_ONLY
RUN_WITH_TIMEOUT 5 1 sync || LOG_WARN "$0" 0 "HALT" "Final disk sync did not complete"

LOG_INFO "$0" 0 "HALT" "$(printf "Handing off to %s -f" "$ACTION")"
"$ACTION" -f

case "$BOARD_NAME" in
	rg*) echo 0x1801 >"/sys/class/axp/axp_reg" ;;
esac
