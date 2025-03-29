#!/bin/sh
# shellcheck disable=SC2086

case ":$LD_LIBRARY_PATH:" in
	*":/opt/muos/extra/lib:"*) ;;
	*) export LD_LIBRARY_PATH="/opt/muos/extra/lib:$LD_LIBRARY_PATH" ;;
esac

GLOBAL_CONFIG="/opt/muos/config/config.ini"
KIOSK_CONFIG="/opt/muos/config/kiosk.ini"
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
PIPEWIRE_RUNTIME_DIR="/var/run"
XDG_RUNTIME_DIR="/var/run"
DEVICE_TYPE=$(tr '[:upper:]' '[:lower:]' <"/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE_TYPE/config.ini"
DEVICE_CONTROL_DIR="/opt/muos/device/$DEVICE_TYPE/control"
MUOS_BOOT_LOG="/opt/muos/boot.log"
ALSA_CONFIG="/usr/share/alsa/alsa.conf"
WPA_CONFIG="/etc/wpa_supplicant.conf"
MUOS_LOG_DIR="/opt/muos/log"

export GLOBAL_CONFIG KIOSK_CONFIG DBUS_SESSION_BUS_ADDRESS PIPEWIRE_RUNTIME_DIR XDG_RUNTIME_DIR \
	DEVICE_TYPE DEVICE_CONFIG DEVICE_CONTROL_DIR MUOS_BOOT_LOG ALSA_CONFIG WPA_CONFIG

mkdir -p "$MUOS_LOG_DIR"

ESC=$(printf '\x1b')
CSI="${ESC}[38;5;"

SAFE_QUIT=/tmp/safe_quit
EXIT_STATUS=0
PREVIOUS_MODULE=""

EXEC_MUX() {
	[ -f "$SAFE_QUIT" ] && rm "$SAFE_QUIT"
	EXIT_STATUS=0
	GOBACK="$1"
	MODULE="$2"
	shift

	[ -n "$GOBACK" ] && echo "$GOBACK" >"$ACT_GO"

	SET_VAR "system" "foreground_process" "$MODULE"
	nice --20 "/opt/muos/extra/$MODULE" "$@"

	while [ ! -f "$SAFE_QUIT" ]; do /opt/muos/bin/toybox sleep 0.1; done
	PREVIOUS_MODULE="$MODULE"
	EXIT_STATUS=$(head -n 1 "$SAFE_QUIT")
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
	cat "/run/muos/$1/$2" 2>/dev/null
}

LOG() {
	SYMBOL="$1"
	MODULE="$(basename "$2" ".sh")"
	PROGRESS="$3"
	TITLE="$4"
	shift 4

	MSG="$1"
	shift

	SPACER=$(printf "%-10s\t" "$TITLE")
	[ -z "$TITLE" ] && SPACER=$(printf "\t")

	printf "[%6s] [%-3s${ESC}[0m] %s${MSG}\n" "$(UPTIME)" "$SYMBOL" "$SPACER" "$@"
	printf "[%6s] [%-3s${ESC}[0m] %s${MSG}\n" "$(UPTIME)" "$SYMBOL" "$SPACER" "$@" >>"$MUOS_LOG_DIR/$(date +"%Y_%m_%d")_$MODULE.log"
	# /opt/muos/extra/muxstart $PROGRESS "$(printf "%s\n\n%s${MSG}" "$TITLE" "$@")"
}

LOG_INFO() { (LOG "${CSI}33m*" "$@") & }
LOG_WARN() { (LOG "${CSI}226m!" "$@") & }
LOG_ERROR() { (LOG "${CSI}196m-" "$@") & }
LOG_SUCCESS() { (LOG "${CSI}46m+" "$@") & }
LOG_DEBUG() { (LOG "${CSI}202m?" "$@") & }

CRITICAL_FAILURE() {
	case "$1" in
		mount) MESSAGE=$(printf "Critical Failure\n\nFailed to mount directory!") ;;
		udev) MESSAGE=$(printf "Critical Failure\n\nFailed to initialise udev!") ;;
		*) MESSAGE=$(printf "Critical Failure\n\nAn unknown error occurred!") ;;
	esac

	/opt/muos/extra/muxstart 0 "$MESSAGE"
	/opt/muos/bin/toybox sleep 10
	/opt/muos/script/system/halt.sh poweroff
}

RUMBLE() {
	echo 1 >"$1"
	/opt/muos/bin/toybox sleep "$2"
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

	for MODE in screen mux; do
		SET_VAR "device" "$MODE/width" "$WIDTH"
		SET_VAR "device" "$MODE/height" "$HEIGHT"
	done

	if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 0 ] && [ "$(GET_VAR "device" "board/name")" = "rg28xx-h" ]; then
		TMP_W="$WIDTH"
		WIDTH="$HEIGHT"
		HEIGHT="$TMP_W"
	fi

	/opt/muos/extra/mufbset -w "$WIDTH" -h "$HEIGHT" -d "$DEPTH"
}

HDMI_SWITCH() {
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
			WIDTH="$(GET_VAR "device" "screen/internal/width")"
			HEIGHT="$(GET_VAR "device" "screen/internal/height")"
			;;
	esac

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
