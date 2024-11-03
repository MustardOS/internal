#!/bin/sh

. /opt/muos/script/var/init/system.sh

ESC=$(printf '\x1b')
CSI="${ESC}[38;5;"

FB_SWITCH() {
	WIDTH="$1"
	HEIGHT="$2"
	DEPTH="$3"

	echo 4 >/sys/class/graphics/fb0/blank
	cat /dev/zero >/dev/fb0 2>/dev/null

	fbset -fb /dev/fb0 -g 0 0 0 0 "${DEPTH}"
	sleep 0.25
	fbset -fb /dev/fb0 -g "${WIDTH}" "${HEIGHT}" "${WIDTH}" "$((HEIGHT * 2))" "${DEPTH}"
	sleep 0.25

	echo 0 >/sys/class/graphics/fb0/blank
}

# Writes a setting value to the display driver.
#
# Usage: DISPLAY_WRITE NAME COMMAND PARAM
DISPLAY_WRITE() {
	printf '%s\n' "$1" >/sys/kernel/debug/dispdbg/name
	printf '%s\n' "$2" >/sys/kernel/debug/dispdbg/command
	printf '%s\n' "$3" >/sys/kernel/debug/dispdbg/param
	echo 1 >/sys/kernel/debug/dispdbg/start
}

# Reads and prints a setting value from the display driver.
#
# Usage: DISPLAY_READ NAME COMMAND
DISPLAY_READ() {
	printf '%s\n' "$1" >/sys/kernel/debug/dispdbg/name
	printf '%s\n' "$2" >/sys/kernel/debug/dispdbg/command
	echo 1 >/sys/kernel/debug/dispdbg/start
	cat /sys/kernel/debug/dispdbg/info
}

# Prints current system uptime in hundredths of a second. Unlike date or
# EPOCHREALTIME, this won't decrease if the system clock is set back, so it can
# be used to measure an interval of real time.
UPTIME() {
	cut -d ' ' -f 1 /proc/uptime
}

PARSE_INI() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^${KEY}[ ]*=[ ]*/ { s/^[^=]*=[ ]*//; p; q; }; n; b l; }" "${INI_FILE}"
}

SET_VAR() {
	printf "%s" "$3" >"/run/muos/$1/$2"
}

GET_VAR() {
	cat "/run/muos/$1/$2"
}

LOG() {
	SYMBOL="$1"               # The symbol for the specific log type
	MODULE="$(basename "$2")" # This is the name of the calling script without the full path
	PROGRESS="$3"             # Used mainly for muxstart to show the progress line
	TITLE="$4"                # The header of what is being logged - generally for sorting purposes
	shift 4

	# Extract the message format string since we can add things like %s %d etc
	MSG="$1"
	shift

	# Time is of the essence!
	TIME=$(date '+%Y-%m-%d %H:%M:%S')

	if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 1 ]; then
		/opt/muos/extra/muxstart "$PROGRESS" "$(printf "%s\n\n${MSG}\n" "$TITLE" "$@")" && sleep 0.5
	fi

	# Print to console and log file and ensure the message is formatted correctly with printf options
	printf "[%s] [%s${ESC}[0m] [%s] %s - ${MSG}\n" "$TIME" "$SYMBOL" "$MODULE" "$TITLE" "$@" | tee -a "$MUOS_BOOT_LOG"
}

LOG_INFO() { LOG "${CSI}33m*" "$@"; }
LOG_WARN() { LOG "${CSI}226m!" "$@"; }
LOG_ERROR() { LOG "${CSI}196m-" "$@"; }
LOG_SUCCESS() { LOG "${CSI}46m+" "$@"; }
LOG_DEBUG() { LOG "${CSI}202m?" "$@"; }

CRITICAL_FAILURE() {
	case "$1" in
		device) MESSAGE=$(printf "Critical Failure\n\nFailed to mount '%s'!\n\n%s" "$2" "$3") ;;
		directory) MESSAGE=$(printf "Critical Failure\n\nFailed to mount '%s' on '%s'!" "$2" "$3") ;;
		udev) MESSAGE="Critical Failure\n\nFailed to initialise udev!" ;;
		*) MESSAGE="Critical Failure\n\nAn unknown error occurred!" ;;
	esac

	/opt/muos/extra/muxstart "$MESSAGE"
	sleep 10
	/opt/muos/script/system/halt.sh poweroff
}

RUMBLE() {
	echo 1 >"$1"
	sleep "$2"
	echo 0 >"$1"
}
