#!/bin/sh
# shellcheck disable=SC2086

case ":$LD_LIBRARY_PATH:" in
	*":/opt/muos/frontend/lib:"*) ;;
	*) export LD_LIBRARY_PATH="/opt/muos/frontend/lib:$LD_LIBRARY_PATH" ;;
esac

HOME="/root"
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
PIPEWIRE_RUNTIME_DIR="/var/run"
XDG_RUNTIME_DIR="$PIPEWIRE_RUNTIME_DIR"
ALSA_CONFIG="/usr/share/alsa/alsa.conf"
WPA_CONFIG="/etc/wpa_supplicant.conf"
DEVICE_CONTROL_DIR="/opt/muos/device/control"
MUOS_LOG_DIR="/opt/muos/log"
LED_CONTROL_SCRIPT="/opt/muos/script/device/rgb.sh"
MUOS_SHARE_DIR="/opt/muos/share"
MUOS_STORE_DIR="/run/muos/storage"

export HOME DBUS_SESSION_BUS_ADDRESS PIPEWIRE_RUNTIME_DIR XDG_RUNTIME_DIR \
	ALSA_CONFIG WPA_CONFIG DEVICE_CONTROL_DIR MUOS_LOG_DIR LED_CONTROL_SCRIPT \
	MUOS_SHARE_DIR MUOS_STORE_DIR

mkdir -p "$MUOS_LOG_DIR"

ESC=$(printf '\x1b')
CSI="${ESC}[38;5;"

SAFE_QUIT=/tmp/safe_quit

CAPITALISE() {
	printf '%s' "$1" | sed 's/\(^\|[[:space:]]\)\([[:alpha:]]\)/\1\u\2/g'
}

TBOX() {
	CMD=$1
	shift

	/opt/muos/bin/toybox "$CMD" "$@"
}

GET_CONF_PATH() {
	case "$1" in
		global | config) echo "/opt/muos/config" ;;
		device) echo "/opt/muos/device/config" ;;
		kiosk) echo "/opt/muos/kiosk" ;;
		system) echo "/opt/muos/config/system" ;;
	esac
}

SET_VAR() {
	BASE=$(GET_CONF_PATH "$1") || return 0
	printf "%s" "$3" >"$BASE/$2"
}

GET_VAR() {
	BASE="$(GET_CONF_PATH "$1")" || return 0

	FILE="$BASE/$2"
	[ -r "$FILE" ] || return 0

	VAL=
	IFS= read -r VAL <"$FILE"

	CR=$(printf "\r")
	[ "${VAL%$CR}" != "$VAL" ] && VAL=${VAL%$CR}

	printf "%s" "$VAL"
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

ENSURE_REMOVED() {
	P="$1"
	C=0

	while [ -e "$P" ] && [ "$C" -lt 10 ]; do
		rm -f -- "$P" 2>/dev/null || :

		[ -e "$P" ] || break

		C=$((C + 1))
		TBOX sleep 0.1
	done
}

GET_FRONTEND_PIDS() {
	MUX="$(pgrep -x muxfrontend 2>/dev/null || :)"
	FRO="$(pgrep -x frontend.sh 2>/dev/null || :)"

	[ -n "$MUX" ] && printf '%s\n' "$MUX"
	[ -n "$FRO" ] && printf '%s\n' "$FRO"
}

FRONTEND_RUNNING() {
	PIDS="$(GET_FRONTEND_PIDS)"
	[ -n "$PIDS" ]
}

SIGNAL_FRONTEND() {
	SIG="$1"
	PIDS="$(GET_FRONTEND_PIDS)"

	[ -z "$PIDS" ] && return 0

	for PID in $PIDS; do
		kill "-$SIG" "$PID" 2>/dev/null || :
	done
}

FRONTEND() {
	case "$1" in
		stop)
			[ -n "$SAFE_QUIT" ] && { : >"$SAFE_QUIT" 2>/dev/null || :; }

			SIGNAL_FRONTEND USR1

			I=5
			while FRONTEND_RUNNING && [ "$I" -gt 0 ]; do
				TBOX sleep 1
				I=$((I - 1))
			done

			if FRONTEND_RUNNING; then
				SIGNAL_FRONTEND TERM

				J=3
				while FRONTEND_RUNNING && [ "$J" -gt 0 ]; do
					TBOX sleep 1
					J=$((J - 1))
				done
			fi

			if FRONTEND_RUNNING; then
				SIGNAL_FRONTEND KILL
			fi
			;;
		start)
			if FRONTEND_RUNNING; then
				return 0
			fi

			if [ -n "$2" ]; then
				setsid -f /opt/muos/script/mux/frontend.sh "$2" </dev/null >/dev/null 2>&1
			else
				setsid -f /opt/muos/script/mux/frontend.sh </dev/null >/dev/null 2>&1
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

HOTKEY() {
	case "$1" in
		stop)
			while pgrep -x muhotkey >/dev/null || pgrep -x hotkey.sh >/dev/null; do
				killall -9 muhotkey hotkey.sh
				TBOX sleep 1
			done
			;;
		start)
			pgrep -x muhotkey >/dev/null && return 0
			setsid -f /opt/muos/script/mux/hotkey.sh </dev/null >/dev/null 2>&1
			;;
		restart)
			HOTKEY stop
			HOTKEY start
			;;
		*)
			printf "Usage: HOTKEY start | stop | restart\n"
			return 1
			;;
	esac
}

EXEC_MUX() {
	if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
		while [ ! -f "/tmp/hdmi_in_use" ]; do TBOX sleep 0.1; done
	fi

	[ -f "$SAFE_QUIT" ] && rm "$SAFE_QUIT"

	GOBACK="$1"
	MODULE="$2"
	shift

	[ -n "$GOBACK" ] && echo "$GOBACK" >"$ACT_GO"

	SET_VAR "system" "foreground_process" "$MODULE"
	nice --20 "/opt/muos/frontend/$MODULE" "$@"

	while [ ! -f "$SAFE_QUIT" ]; do TBOX sleep 0.1; done
}

# Prints current system uptime in hundredths of a second. Unlike date or
# EPOCHREALTIME, this won't decrease if the system clock is set back, so it can
# be used to measure an interval of real time.
UPTIME() {
	cut -d ' ' -f 1 /proc/uptime
}

DELETE_CRUFT() {
	[ "$1" ] || return

	find "$1" -type d \( \
		-name 'System Volume Information' -o \
		-name '.Trashes' -o \
		-name '.Spotlight' -o \
		-name '.fseventsd' \
		\) -exec rm -rf -- {} \;

	find "$1" -type f \( \
		-name '._*' -o \
		-name '.DS_Store' -o \
		-name 'desktop.ini' -o \
		-name 'Thumbs.db' -o \
		-name '.DStore' -o \
		-name '.gitkeep' \
		\) -exec rm -f -- {} \;
}

PARSE_INI() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^${KEY}[ ]*=[ ]*/ { s/^[^=]*=[ ]*//; p; q; }; n; b l; }" "${INI_FILE}"
}

LOG() {
	SYMBOL="$1"
	MODULE="$(basename "$2")"
	PROGRESS="$3"
	TITLE="$4"
	shift 4

	MSG="$1"
	shift

	TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
	[ -d "$MUOS_LOG_DIR" ] || mkdir -p "$MUOS_LOG_DIR"
	LOG_FILE="$MUOS_LOG_DIR/$(date +"%Y_%m_%d")_$MODULE.log"

	[ "$#" -gt 0 ] && EXTRA="$*" || EXTRA=""

	LOG_LINE=$(printf "[%s]\t[%s] [%s%s] [%s]\t" "$(UPTIME)" "$TIMESTAMP" "$SYMBOL" "${ESC}[0m" "$MODULE")
	LOG_LINE="$LOG_LINE$MSG $EXTRA"

	printf "%s\n" "$LOG_LINE" | tee -a "$LOG_FILE"

	# /opt/muos/frontend/muxmessage $PROGRESS "$(printf "%s\n\n%s %s" "$TITLE" "$MSG" "$*")"
}

DEBUG_MODE=$(GET_VAR "system" "debug_mode" 2>/dev/null || echo 0)
if [ "$DEBUG_MODE" -eq 0 ]; then
	LOG_INFO() { :; }
	LOG_WARN() { LOG "${CSI}226m!" "$@"; }
	LOG_ERROR() { LOG "${CSI}196m-" "$@"; }
	LOG_SUCCESS() { :; }
	LOG_DEBUG() { :; }
else
	LOG_INFO() { LOG "${CSI}33m*" "$@"; }
	LOG_WARN() { LOG "${CSI}226m!" "$@"; }
	LOG_ERROR() { LOG "${CSI}196m-" "$@"; }
	LOG_SUCCESS() { LOG "${CSI}46m+" "$@"; }
	LOG_DEBUG() { LOG "${CSI}202m?" "$@"; }
fi

CRITICAL_FAILURE() {
	case "$1" in
		mount) MESSAGE=$(printf "Critical Failure\n\nFailed to mount directory!") ;;
		udev) MESSAGE=$(printf "Critical Failure\n\nFailed to initialise udev!") ;;
		*) MESSAGE=$(printf "Critical Failure\n\nAn unknown error occurred!") ;;
	esac

	/opt/muos/frontend/muxmessage 0 "$MESSAGE"
	TBOX sleep 10
	/opt/muos/script/system/halt.sh poweroff
}

RUMBLE() {
	if [ -n "$(GET_VAR "device" "board/rumble")" ]; then
		case "$(GET_VAR "device" "board/name")" in
			rk*)
				echo 1 >"$1"
				TBOX sleep "$2"
				echo 1000000 >"$1"
				;;
			*)
				echo 1 >"$1"
				TBOX sleep "$2"
				echo 0 >"$1"
				;;
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

	/opt/muos/frontend/mufbset -w "$WIDTH" -h "$HEIGHT" -d "$DEPTH"
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
	[ "$(GET_VAR "config" "boot/device_mode")" -eq 0 ]
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

LCD_DISABLE() {
	if [ "$(GET_VAR "config" "settings/advanced/disp_suspend")" -eq 1 ]; then
		TBOX sleep 0.5
		DISPLAY_WRITE lcd0 disable 0
		TBOX sleep 0.5
	fi
}

LCD_ENABLE() {
	if [ "$(GET_VAR "config" "settings/advanced/disp_suspend")" -eq 1 ]; then
		TBOX sleep 0.5
		DISPLAY_WRITE lcd0 enable 0
		TBOX sleep 0.5
	fi
}

PLAY_SOUND() {
	SND="$MUOS_SHARE_DIR/media/$1.wav"
	[ -e "$SND" ] && ENSURE_REMOVED "$SND"

	case "$(GET_VAR "config" "settings/general/sound")" in
		1)
			WAV="$MUOS_SHARE_DIR/media/sound/$1.wav"
			[ -e "$WAV" ] && cp "$WAV" "$SND"
			;;
		2)
			WAV="$MUOS_STORE_DIR/theme/active/sound/$1.wav"
			[ -e "$WAV" ] && cp "$WAV" "$SND"
			;;
		*) ;;
	esac

	[ -e "$SND" ] && /usr/bin/mpv --really-quiet "$SND"
}

SETUP_SDL_ENVIRONMENT() {
	REQ_STYLE=""
	SKIP_BLITTER=0

	for A in "$@"; do
		case "$A" in
			retro | modern) REQ_STYLE="$A" ;; # Optional priority override: $1 = retro | modern
			skip_blitter) SKIP_BLITTER=1 ;;   # Used primarily for external ScummVM at the moment
		esac
	done

	GCDB_DEFAULT="/usr/lib/gamecontrollerdb.txt"
	GCDB_STORE="$MUOS_SHARE_DIR/info/gamecontrollerdb"

	# Decide controller DB (priority: arg -> /tmp/con_go -> default)
	case "$REQ_STYLE" in
		modern) SDL_GAMECONTROLLERCONFIG_FILE="$GCDB_STORE/modern.txt" ;;
		retro) SDL_GAMECONTROLLERCONFIG_FILE="$GCDB_STORE/retro.txt" ;;
		*)
			CON_GO="/tmp/con_go"
			if [ -e "$CON_GO" ]; then
				SEL="$(cat "$CON_GO")"
				case "$SEL" in
					# honour "system" - otherwise use whatever was selected from content...
					system)
						if [ "$(GET_VAR "config" "settings/advanced/swap")" -eq 1 ]; then
							SDL_GAMECONTROLLERCONFIG_FILE="$GCDB_STORE/modern.txt"
						else
							SDL_GAMECONTROLLERCONFIG_FILE="$GCDB_STORE/retro.txt"
						fi
						;;
					*) SDL_GAMECONTROLLERCONFIG_FILE="$GCDB_STORE/$SEL" ;;
				esac
			else
				SDL_GAMECONTROLLERCONFIG_FILE="$GCDB_DEFAULT"
			fi
			;;
	esac

	# Set both the SDL controller file and configuration
	[ ! -r "$SDL_GAMECONTROLLERCONFIG_FILE" ] && SDL_GAMECONTROLLERCONFIG_FILE="$GCDB_DEFAULT"
	SDL_GAMECONTROLLERCONFIG=$(grep "$(GET_VAR "device" "sdl/name")" "$SDL_GAMECONTROLLERCONFIG_FILE")

	export SDL_GAMECONTROLLERCONFIG_FILE SDL_GAMECONTROLLERCONFIG

	if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
		SDL_HQ_SCALER=2
		SDL_ROTATION=0
		[ "$SKIP_BLITTER" -eq 0 ] && SDL_BLITTER_DISABLED=1
	else
		SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
		SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
		[ "$SKIP_BLITTER" -eq 0 ] && SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
	fi

	SDL_ASSERT=always_ignore

	if [ "$SKIP_BLITTER" -eq 0 ]; then
		export SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
	else
		export SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION
	fi
}

UPDATE_RA_VALUE() {
	BUTTON_NAME=$1
	EXPECTED_VALUE=$2
	RA_DEV_CONF=$3

	# Read and update current value if it doesn't match the expected value
	if ! grep -q "^$BUTTON_NAME = \"$EXPECTED_VALUE\"" "$RA_DEV_CONF"; then
		sed -i "s|^$BUTTON_NAME = \".*\"|$BUTTON_NAME = \"$EXPECTED_VALUE\"|" "$RA_DEV_CONF"
	fi
}

DETECT_CONTROL_SWAP() {
	RA_DEV_CONF="/opt/muos/device/control/retroarch.device.cfg"
	CON_GO="/tmp/con_go"
	IS_SWAP=0

	DO_SWAP() {
		/opt/muos/script/mux/swap_abxy.sh "$RA_DEV_CONF"
		IS_SWAP=1
	}

	if [ -e "$CON_GO" ]; then
		case "$(cat "$CON_GO")" in
			modern) DO_SWAP ;;
			retro) ;;
			*) [ "$(GET_VAR "config" "settings/advanced/swap")" -eq 1 ] && DO_SWAP ;;
		esac
	fi

	echo $IS_SWAP
}

CONFIGURE_RETROARCH() {
	RA_CONF="$MUOS_SHARE_DIR/info/config/retroarch.cfg"
	RA_DEF="$MUOS_SHARE_DIR/emulator/retroarch/retroarch.default.cfg"
	RA_CONTROL="/opt/muos/device/control/retroarch"

	# Stop the user from doing anything harmful to the main RetroArch configuration.
	[ "$(GET_VAR "config" "settings/advanced/retrofree")" -eq 0 ] && rm -f "$RA_CONF"

	# Check if the default RetroArch configuration exists.
	[ ! -f "$RA_CONF" ] && cp "$RA_DEF" "$RA_CONF"

	# Set the device specific SDL Controller Map
	/opt/muos/script/mux/sdl_map.sh

	# Modify the RetroArch settings for device resolution output
	RA_WIDTH="$(GET_VAR "device" "screen/width")"
	RA_HEIGHT="$(GET_VAR "device" "screen/height")"

	(
		printf "video_fullscreen_x = \"%s\"\n" "$RA_WIDTH"
		printf "video_fullscreen_y = \"%s\"\n" "$RA_HEIGHT"
		printf "video_window_auto_width_max = \"%s\"\n" "$RA_WIDTH"
		printf "video_window_auto_height_max = \"%s\"\n" "$RA_HEIGHT"
		printf "custom_viewport_width = \"%s\"\n" "$RA_WIDTH"
		printf "custom_viewport_height = \"%s\"\n" "$RA_HEIGHT"
		if [ "$RA_WIDTH" -ge 1280 ]; then
			printf "rgui_aspect_ratio = \"%s\"" "1"
		else
			printf "rgui_aspect_ratio = \"%s\"" "0"
		fi
	) >"$RA_CONTROL.resolution.cfg"

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

	# Re-define the symlink to current configuration.
	HOME_CFG="$(GET_VAR "device" "board/home")/.config"
	rm -rf "$HOME_CFG/retroarch" # Purge it just in case it was created by something else!
	ln -s "$MUOS_SHARE_DIR/emulator/retroarch" "$HOME_CFG/retroarch"
	ln -s "$MUOS_SHARE_DIR/info/config/retroarch.cfg" "$HOME_CFG/retroarch/retroarch.cfg"

	EXTRA_ARGS=""
	APPEND_LIST=""

	# The following will stop auto load from happening if they hold A on content
	AUTOLOAD_CONF="$(dirname "$RA_CONF")/retroarch.autoload.cfg"
	if [ -e "/tmp/ra_no_load" ]; then
		printf "savestate_auto_load = \"false\"\n" >"$AUTOLOAD_CONF"
		APPEND_LIST="${APPEND_LIST}${APPEND_LIST:+|}$AUTOLOAD_CONF"
	fi

	# The following will load a users retro achievement settings if saved
	CHEEVOS_CONF="$(dirname "$RA_CONF")/retroarch.cheevos.cfg"
	[ -e "$CHEEVOS_CONF" ] && APPEND_LIST="${APPEND_LIST}${APPEND_LIST:+|}$CHEEVOS_CONF"

	[ -n "$APPEND_LIST" ] && EXTRA_ARGS="--appendconfig=$APPEND_LIST"
	echo "$EXTRA_ARGS"
}

KERNEL_TUNING() {
	GET_VAR "config" "danger/vmswap" >"/proc/sys/vm/swappiness"
	GET_VAR "config" "danger/dirty_ratio" >"/proc/sys/vm/dirty_ratio"
	GET_VAR "config" "danger/dirty_back_ratio" >"/proc/sys/vm/dirty_background_ratio"
	GET_VAR "config" "danger/cache_pressure" >"/proc/sys/vm/vfs_cache_pressure"

	GET_VAR "config" "danger/nomerges" >"/sys/block/$1/queue/nomerges"
	GET_VAR "config" "danger/nr_requests" >"/sys/block/$1/queue/nr_requests"
	GET_VAR "config" "danger/iostats" >"/sys/block/$1/queue/iostats"

	GET_VAR "config" "danger/idle_flush" >"/proc/sys/vm/laptop_mode"
	GET_VAR "config" "danger/page_cluster" >"/proc/sys/vm/page-cluster"
	GET_VAR "config" "danger/child_first" >"/proc/sys/kernel/sched_child_runs_first"
	GET_VAR "config" "danger/time_slice" >"/proc/sys/kernel/sched_rr_timeslice_ms"
	GET_VAR "config" "danger/tune_scale" >"/proc/sys/kernel/sched_tunable_scaling"

	blockdev --setra "$(GET_VAR "config" "danger/read_ahead")" "/dev/$1"
}

LED_CONTROL_CHANGE() {
(
    if [ "$(GET_VAR "device" "led/rgb")" -eq 1 ]; then
        if [ "$(GET_VAR "config" "settings/general/rgb")" -eq 1 ]; then
            RGBCONF_SCRIPT="$MUOS_STORE_DIR/theme/active/rgb/rgbconf.sh"
            TIMEOUT=10
            WAIT=0

            while [ ! -f "$RGBCONF_SCRIPT" ] && [ "$WAIT" -lt "$TIMEOUT" ]; do
                TBOX sleep 1
                WAIT=$((WAIT + 1))
            done

            if [ -f "$RGBCONF_SCRIPT" ]; then
                "$RGBCONF_SCRIPT"
            elif [ -f "$LED_CONTROL_SCRIPT" ]; then
                "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
            fi
        else
            [ -f "$LED_CONTROL_SCRIPT" ] && "$LED_CONTROL_SCRIPT" 1 0 0 0 0 0 0 0
        fi
    fi
) &
}

UPDATE_BOOTLOGO() {
	BOOT_MOUNT="$(GET_VAR "device" "storage/boot/mount")"

	DEVICE_W=$(GET_VAR "device" "screen/internal/width")
	DEVICE_H=$(GET_VAR "device" "screen/internal/height")

	SPEC_BL="$MUOS_STORE_DIR/theme/active/${DEVICE_W}x${DEVICE_H}/image/bootlogo.bmp"
	NORM_BL="$MUOS_STORE_DIR/theme/active/image/bootlogo.bmp"

	if [ -e "$SPEC_BL" ]; then
		printf "\nBootlogo found at: %s\n" "$SPEC_BL"
		cp -f "$SPEC_BL" "$BOOT_MOUNT/bootlogo.bmp"
	else
		if [ -e "$NORM_BL" ]; then
			printf "\nBootlogo found at: %s\n" "$NORM_BL"
			cp -f "$NORM_BL" "$BOOT_MOUNT/bootlogo.bmp"
		else
			printf "\nReverting to system bootlogo: %s\n" "$NORM_BL"
			cp -f "${MUOS_SHARE_DIR}/bootlogo/${DEVICE_W}x${DEVICE_H}/bootlogo.bmp" "$BOOT_MOUNT/bootlogo.bmp"
		fi
	fi

	BL_ROTATE=0

	case "$(GET_VAR "device" "board/name")" in
		rg28xx-h)
			BL_ROTATE=1
			convert "$BOOTLOGO_MOUNT/bootlogo.bmp" -rotate 270 "$BOOTLOGO_MOUNT/bootlogo.bmp"
			;;
	esac

	[ $BL_ROTATE -ne 0 ] && printf "\nRotated Bootlogo Image\n"
}
