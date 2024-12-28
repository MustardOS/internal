#!/bin/sh
# shellcheck disable=SC2086

. /opt/muos/script/var/init/system.sh

ESC=$(printf '\x1b')
CSI="${ESC}[38;5;"

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
	shift 3

	TIMING_ARGS=""
	[ "$#" -gt 0 ] && TIMING_ARGS="-t $*"

	SET_VAR "device" "screen/width" "$WIDTH"
	SET_VAR "device" "screen/height" "$HEIGHT"
	SET_VAR "device" "mux/width" "$WIDTH"
	SET_VAR "device" "mux/height" "$HEIGHT"

	fbset -fb "$(GET_VAR "device" "screen/device")" -g "${WIDTH}" "${HEIGHT}" "${WIDTH}" "$((HEIGHT * 2))" "${DEPTH}" $TIMING_ARGS
}

HDMI_SWITCH() {
	LQ_TIMING="25175 40 24 32 9 96 2"
	HQ_TIMING="13468 220 40 20 5 110 5"

	case "$(GET_VAR "global" "settings/hdmi/resolution")" in
		0 | 2)
			SET_VAR "device" "screen/external/width" 640
			SET_VAR "device" "screen/external/height" 480
			FB_SWITCH 640 480 32 $LQ_TIMING
			;;
		1 | 3)
			SET_VAR "device" "screen/external/width" 720
			SET_VAR "device" "screen/external/height" 576
			FB_SWITCH 720 576 32 $LQ_TIMING
			;;
		4 | 5)
			SET_VAR "device" "screen/external/width" 1280
			SET_VAR "device" "screen/external/height" 720
			FB_SWITCH 1280 720 32 $HQ_TIMING
			;;
		6 | 7 | 8 | 9 | 10)
			SET_VAR "device" "screen/external/width" 1920
			SET_VAR "device" "screen/external/height" 1080
			FB_SWITCH 1920 1080 32 $HQ_TIMING
			;;
		*) FB_SWITCH "$(GET_VAR "device" "screen/internal/width")" "$(GET_VAR "device" "screen/internal/height")" 32 $LQ_TIMING ;;
	esac
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
