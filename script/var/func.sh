#!/bin/sh

. /opt/muos/script/var/init/system.sh

FB_SWITCH() {
	WIDTH="$1"
	HEIGHT="$2"
	DEPTH="$3"

	echo 4 >/sys/class/graphics/fb0/blank
	cat /dev/zero >/dev/fb0 2>/dev/null

	VIRTUAL_HEIGHT=$((HEIGHT * 2))

	fbset -fb /dev/fb0 -g "${WIDTH}" "${HEIGHT}" "${WIDTH}" "${VIRTUAL_HEIGHT}" "${DEPTH}"
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

LOGGER() {
	if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 1 ]; then
		/opt/muos/extra/muxstart "$(printf "%s\n\n%s\n" "$2" "$3")" && sleep 0.5
	fi
	printf "%s\t[%s] :: %s - %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$1" "$2" "$3" >>"$MUOS_BOOT_LOG"
}

DEVICE_MOUNT_FAILURE() {
	/opt/muos/extra/muxstart "$(printf "Critical Mount Failure\n\nFailed to mount '%s'!\n\n%s" "$1" "$2")"
	sleep infinity
}

DIRECTORY_MOUNT_FAILURE() {
	/opt/muos/extra/muxstart "$(printf "Critical Mount Failure\n\nFailed to mount '%s' on '%s'!" "$1" "$2")"
	sleep infinity
}
