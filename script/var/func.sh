#!/bin/sh
# shellcheck disable=SC2086

MP="/opt/muos"

case ":$LD_LIBRARY_PATH:" in
	*":$MP/extra/lib:"*) ;;
	*) export LD_LIBRARY_PATH="$MP/extra/lib:$LD_LIBRARY_PATH" ;;
esac

HOME="/root"
KIOSK_CONFIG="$MP/config/kiosk.ini"
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
PIPEWIRE_RUNTIME_DIR="/var/run"
XDG_RUNTIME_DIR="$PIPEWIRE_RUNTIME_DIR"
ALSA_CONFIG="/usr/share/alsa/alsa.conf"
WPA_CONFIG="/etc/wpa_supplicant.conf"
DEVICE_CONTROL_DIR="$MP/device/control"
MUOS_LOG_DIR="$MP/log"

export HOME KIOSK_CONFIG DBUS_SESSION_BUS_ADDRESS PIPEWIRE_RUNTIME_DIR \
	XDG_RUNTIME_DIR ALSA_CONFIG WPA_CONFIG DEVICE_CONTROL_DIR MUOS_LOG_DIR

mkdir -p "$MUOS_LOG_DIR"

ESC=$(printf '\x1b')
CSI="${ESC}[38;5;"

SAFE_QUIT=/tmp/safe_quit
EXIT_STATUS=0
PREVIOUS_MODULE=""

GET_CONF_PATH() {
	case "$1" in
		global | config) echo "$MP/config" ;;
		device) echo "$MP/device/config" ;;
		kiosk) echo "$MP/kiosk" ;;
		system) echo "$MP/config/system" ;;
	esac
}

SET_VAR() {
	BASE=$(GET_CONF_PATH "$1") || return 0
	printf "%s" "$3" >"$BASE/$2"
}

GET_VAR() {
	BASE=$(GET_CONF_PATH "$1") || return 0
	cat "$BASE/$2" 2>/dev/null
}

SET_DEFAULT_GOVERNOR() {
	DEF_GOV=$(GET_VAR "device" "cpu/default")
	printf '%s' "$DEF_GOV" >"$(GET_VAR "device" "cpu/governor")"
	if [ "$DEF_GOV" = ondemand ]; then
		GET_VAR "device" "cpu/min_freq_default" >"$(GET_VAR "device" "cpu/min_freq")"
		GET_VAR "device" "cpu/max_freq_default" >"$(GET_VAR "device" "cpu/max_freq")"
		GET_VAR "device" "cpu/sampling_rate_default" >"$(GET_VAR "device" "cpu/sampling_rate")"
		GET_VAR "device" "cpu/up_threshold_default" >"$(GET_VAR "device" "cpu/up_threshold")"
		GET_VAR "device" "cpu/sampling_down_factor_default" >"$(GET_VAR "device" "cpu/sampling_down_factor")"
		GET_VAR "device" "cpu/io_is_busy_default" >"$(GET_VAR "device" "cpu/io_is_busy")"
	fi
}

FRONTEND() {
	case "$1" in
		stop)
			while pgrep -x frontend.sh >/dev/null || pgrep -x muxfrontend >/dev/null; do
				killall -9 frontend.sh muxfrontend
				$MP/bin/toybox sleep 1
			done
			;;
		start)
			pgrep -x frontend.sh >/dev/null && return 0
			if [ -n "$2" ]; then
				setsid -f $MP/script/mux/frontend.sh "$2" </dev/null >/dev/null 2>&1
			else
				setsid -f $MP/script/mux/frontend.sh </dev/null >/dev/null 2>&1
			fi
			;;
		restart)
			FRONTEND stop
			FRONTEND "$@"
			;;
		*)
			printf "Usage: FRONTEND start [module] | stop | restart [module]\n"
			return 1
			;;
	esac
}

EXEC_MUX() {
	if [ "$(GET_VAR config boot/device_mode)" -eq 1 ]; then
		while [ ! -f "/tmp/hdmi_in_use" ]; do $MP/bin/toybox sleep 0.1; done
	fi

	[ -f "$SAFE_QUIT" ] && rm "$SAFE_QUIT"

	EXIT_STATUS=0
	GOBACK="$1"
	MODULE="$2"
	shift

	[ -n "$GOBACK" ] && echo "$GOBACK" >"$ACT_GO"

	SET_VAR "system" "foreground_process" "$MODULE"
	nice --20 "$MP/extra/$MODULE" "$@"

	while [ ! -f "$SAFE_QUIT" ]; do $MP/bin/toybox sleep 0.1; done

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
	# $MP/extra/muxmessage $PROGRESS "$(printf "%s\n\n%s${MSG}" "$TITLE" "$@")"
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

	$MP/extra/muxmessage 0 "$MESSAGE"
	$MP/bin/toybox sleep 10
	$MP/script/system/halt.sh poweroff
}

RUMBLE() {
	echo 1 >"$1"
	$MP/bin/toybox sleep "$2"
	echo 0 >"$1"
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

	$MP/extra/mufbset -w "$WIDTH" -h "$HEIGHT" -d "$DEPTH"
}

HDMI_SWITCH() {
	WIDTH=0
	HEIGHT=0
	DEPTH=32

	case "$(GET_VAR "config" "settings/hdmi/resolution")" in
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

IS_HANDHELD_MODE() {
	[ "$(GET_VAR config boot/device_mode)" -eq 0 ]
}

# Writes a setting value to the display driver.
# Usage: DISPLAY_WRITE NAME COMMAND PARAM
DISPLAY_WRITE() {
	case "$(GET_VAR "device" "board/name")" in
		rg* | tui*)
			printf "%s" "$1" >/sys/kernel/debug/dispdbg/name
			printf "%s" "$2" >/sys/kernel/debug/dispdbg/command
			printf "%s" "$3" >/sys/kernel/debug/dispdbg/param
			echo 1 >/sys/kernel/debug/dispdbg/start &
			;;
		*) ;;
	esac
}

# Reads and prints a setting value from the display driver.
# Usage: DISPLAY_READ NAME COMMAND
DISPLAY_READ() {
	case "$(GET_VAR "device" "board/name")" in
		rg* | tui*)
			printf "%s" "$1" >/sys/kernel/debug/dispdbg/name
			printf "%s" "$2" >/sys/kernel/debug/dispdbg/command
			echo 1 >/sys/kernel/debug/dispdbg/start
			cat /sys/kernel/debug/dispdbg/info &
			;;
		*) ;;
	esac
}

PLAY_SOUND() {
	SND="/opt/muos/share/media/$1.wav"
	[ -e "$SND" ] && rm -f "$SND"

	case "$NAV_SOUND" in
		1)
			WAV="/mnt/mmc/MUOS/sound/$1.wav"
			[ -e "$WAV" ] && cp "$WAV" "$SND"
			;;
		2)
			WAV="/run/muos/storage/theme/active/sound/$1.wav"
			[ -e "$WAV" ] && cp "$WAV" "$SND"
			;;
		*) ;;
	esac

	[ -e "$SND" ] && /usr/bin/mpv "$SND"
}

SETUP_SDL_ENVIRONMENT() {
	if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
		SDL_HQ_SCALER=2
		SDL_ROTATION=0
		SDL_BLITTER_DISABLED=1
	else
		SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
		SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
		SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
	fi

	export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
}

CONFIGURE_RETROARCH() {
	RA_CONF=$1
	RA_CONTROL="/opt/muos/device/control/retroarch"

	# Include default button mappings from retroarch.device.cfg. Settings in the
	# retroarch.cfg will take precedence. Modified settings will save to the main
	# retroarch.cfg, not the included retroarch.device.cfg file.
	RA_TYPES="device resolution"

	# Create a temporary config file with all matching lines from the original config,
	# excluding any existing include lines for the given RetroArch types in the var.
	TMP_RA_CONF=$(mktemp)
	for TYPE in $RA_TYPES; do
		printf '#include "%s.%s.cfg"\n' "$RA_CONTROL" "$TYPE"
	done | grep -vFf - "$RA_CONF" >"$TMP_RA_CONF"

	# Append the required include lines to the clean config so they are always present.
	for TYPE in $RA_TYPES; do
		printf '#include "%s.%s.cfg"\n' "$RA_CONTROL" "$TYPE" >>"$TMP_RA_CONF"
	done

	# Replace the original config with the modified version.
	mv "$TMP_RA_CONF" "$RA_CONF"

	# Set kiosk mode value based on current configuration.
	KIOSK_MODE=$([ "$(GET_VAR "kiosk" "content/retroarch")" -eq 1 ] && echo true || echo false)
	sed -i "s/^kiosk_mode_enable = \".*\"$/kiosk_mode_enable = \"$KIOSK_MODE\"/" "$RA_CONF"
}
