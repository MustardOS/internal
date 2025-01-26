#!/bin/sh
# shellcheck disable=SC2086

. /opt/muos/script/var/init/system.sh

ESC=$(printf '\x1b')
CSI="${ESC}[38;5;"

SAFE_QUIT=/tmp/safe_quit

EXEC_MUX() {
	[ -f "$SAFE_QUIT" ] && rm "$SAFE_QUIT"

	GOBACK="$1"
	MODULE="$2"
	shift

	[ -n "$GOBACK" ] && echo "$GOBACK" >"$ACT_GO"

	SET_VAR "system" "foreground_process" "$MODULE"
	nice --20 "/opt/muos/extra/$MODULE" "$@"

	while [ ! -f "$SAFE_QUIT" ]; do sleep 0.1; done
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
	[ -f "/run/muos/$1/$2" ] && cat "/run/muos/$1/$2" || echo ""
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
	SPACER="$TITLE - "
	[ -z "$TITLE" ] && SPACER=""
	printf "[%s] [%s${ESC}[0m] [%s] %s${MSG}\n" "$TIME" "$SYMBOL" "$MODULE" "$SPACER" "$@" | tee -a "$MUOS_BOOT_LOG"
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

	/opt/muos/extra/muxstart 0 "$MESSAGE"
	sleep 10
	/opt/muos/script/system/halt.sh poweroff
}

RUMBLE() {
	echo 1 >"$1"
	sleep "$2"
	echo 0 >"$1"
}

STOP_BGM() {
	if pgrep -f "playbgm.sh" >/dev/null; then
		killall -q "playbgm.sh" "mpv"
		printf "%d" "-1" >"/tmp/bgm_type"
	fi
}

START_BGM() {
	NEW_BGM_TYPE=$(GET_VAR "global" "settings/general/bgm")
	OLD_BGM_TYPE=$(cat "/tmp/bgm_type" 2>/dev/null || echo "-1")
	if [ "$NEW_BGM_TYPE" -ne "$OLD_BGM_TYPE" ]; then
		STOP_BGM
		case $NEW_BGM_TYPE in
			1) nohup /opt/muos/script/mux/playbgm.sh "/run/muos/storage/music" & ;;
			2) nohup /opt/muos/script/mux/playbgm.sh "/run/muos/storage/theme/active/music" & ;;
			*) ;;
		esac
		printf "%s" "$NEW_BGM_TYPE" >"/tmp/bgm_type"
	fi
}

CHECK_BGM() {
	if [ "$1" = "ignore" ]; then
		! pgrep -f "playbgm.sh" >/dev/null && START_BGM
	else
		FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
		case "$FG_PROC_VAL" in
			mux*) ! pgrep -f "playbgm.sh" >/dev/null && START_BGM ;;
			*) ;;
		esac
	fi
}

FB_SWITCH() {
	WIDTH="$1"
	HEIGHT="$2"
	DEPTH="$3"
	IGNORE_FILE="/tmp/ignore_double"

	for MODE in screen mux; do
		SET_VAR "device" "$MODE/width" "$WIDTH"
		SET_VAR "device" "$MODE/height" "$HEIGHT"
	done

	if [ "$(GET_VAR "device" "screen/rotate")" -eq 1 ] && [ "$(GET_VAR "global" "settings/hdmi/enabled")" -eq 0 ]; then
		N_WIDTH="$HEIGHT"
		N_HEIGHT="$WIDTH"
	else
		N_WIDTH="$WIDTH"
		N_HEIGHT="$HEIGHT"
	fi

	IGNORE_FLAG=""
	[ -f "$IGNORE_FILE" ] && IGNORE_FLAG="-i"
	/opt/muos/extra/mufbset -w "$N_WIDTH" -h "$N_HEIGHT" -d "$DEPTH" -c $IGNORE_FLAG
	rm -f "$IGNORE_FILE"
}

HDMI_SWITCH() {
	ROTATE=0
	WIDTH=0
	HEIGHT=0
	DEPTH=32

	case "$(GET_VAR "global" "settings/hdmi/resolution")" in
		0 | 2)
			WIDTH=640
			HEIGHT=480
			;;
		1 | 3)
			WIDTH=720
			HEIGHT=576
			;;
		4 | 5)
			WIDTH=1280
			HEIGHT=720
			;;
		6 | 7 | 8 | 9 | 10)
			WIDTH=1920
			HEIGHT=1080
			;;
		*)
			[ "$(GET_VAR "device" "board/name")" = "rg28xx-h" ] && ROTATE=1
			WIDTH="$(GET_VAR "device" "screen/internal/width")"
			HEIGHT="$(GET_VAR "device" "screen/internal/height")"
			;;
	esac

	SET_VAR "device" "screen/rotate" "$ROTATE"
	SET_VAR "device" "screen/external/width" "$WIDTH"
	SET_VAR "device" "screen/external/height" "$HEIGHT"

	FB_SWITCH "$WIDTH" "$HEIGHT" "$DEPTH"
}

# Writes a setting value to the display driver.
#
# Usage: DISPLAY_WRITE NAME COMMAND PARAM
DISPLAY_WRITE() {
	case "$(GET_VAR "device" "board/name")" in
		rg*)
			printf '%s\n' "$1" >/sys/kernel/debug/dispdbg/name
			printf '%s\n' "$2" >/sys/kernel/debug/dispdbg/command
			printf '%s\n' "$3" >/sys/kernel/debug/dispdbg/param
			echo 1 >/sys/kernel/debug/dispdbg/start
			;;
		*) ;;
	esac
}

# Reads and prints a setting value from the display driver.
#
# Usage: DISPLAY_READ NAME COMMAND
DISPLAY_READ() {
	case "$(GET_VAR "device" "board/name")" in
		rg*)
			printf '%s\n' "$1" >/sys/kernel/debug/dispdbg/name
			printf '%s\n' "$2" >/sys/kernel/debug/dispdbg/command
			echo 1 >/sys/kernel/debug/dispdbg/start
			cat /sys/kernel/debug/dispdbg/info
			;;
		*) ;;
	esac
}
