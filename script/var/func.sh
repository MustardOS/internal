#!/bin/sh

MUX_LIB="/opt/muos/frontend/lib"

case ":${LD_LIBRARY_PATH-}:" in
	*":$MUX_LIB:"*) ;;
	*) export LD_LIBRARY_PATH="$MUX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
esac

HOME="/root"
XDG_RUNTIME_DIR="/run"
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
PIPEWIRE_RUNTIME_DIR="/run"
ALSA_CONFIG="/usr/share/alsa/alsa.conf"
WPA_CONFIG="/etc/wpa_supplicant.conf"
DEVICE_CONTROL_DIR="/opt/muos/device/control"
MUOS_LOG_DIR="/opt/muos/log"
MUOS_LOG_BIN="/opt/muos/frontend/mulog"
MUOS_RGB_BIN="/opt/muos/frontend/murgb"
MUOS_RUN_DIR="/run/muos"
MUOS_SHARE_DIR="/opt/muos/share"
MUOS_STORE_DIR="$MUOS_RUN_DIR/storage"
OVERLAY_NOP="$MUOS_RUN_DIR/overlay.disable"
IS_IDLE="$MUOS_RUN_DIR/is_idle"
IDLE_STATE="$MUOS_RUN_DIR/idle_state"

export HOME XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS PIPEWIRE_RUNTIME_DIR \
	ALSA_CONFIG WPA_CONFIG DEVICE_CONTROL_DIR MUOS_LOG_DIR MUOS_LOG_BIN \
	MUOS_RGB_BIN MUOS_RUN_DIR MUOS_SHARE_DIR MUOS_STORE_DIR OVERLAY_NOP \
	IS_IDLE IDLE_STATE

MUOS_CONF_GLOBAL="/opt/muos/config"
MUOS_CONF_DEVICE="/opt/muos/device/config"
MUOS_CONF_KIOSK="/opt/muos/kiosk"
MUOS_CONF_SYSTEM="/opt/muos/config/system"

export MUOS_CONF_GLOBAL MUOS_CONF_DEVICE MUOS_CONF_KIOSK MUOS_CONF_SYSTEM

MESSAGE_EXEC="/opt/muos/frontend/muxmessage"
MESSAGE_TEXT="/tmp/msg_livetext"
MESSAGE_PROG="/tmp/msg_progress"

[ -d "$MUOS_LOG_DIR" ] || mkdir -p "$MUOS_LOG_DIR"
SAFE_QUIT=/tmp/safe_quit

# Module-level CR literal used by GET_VAR to strip trailing carriage returns
CR=$(printf '\r')

CONTENT_UNSET() {
	unset LD_PRELOAD STAGE_OVERLAY SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
}

CAPITALISE() {
	CAP_OUT=
	for CAP_WORD in $1; do
		CAP_FIRST="${CAP_WORD%"${CAP_WORD#?}"}"
		CAP_REST="${CAP_WORD#?}"
		case "$CAP_FIRST" in
			a) CAP_FIRST=A ;; b) CAP_FIRST=B ;; c) CAP_FIRST=C ;;
			d) CAP_FIRST=D ;; e) CAP_FIRST=E ;; f) CAP_FIRST=F ;;
			g) CAP_FIRST=G ;; h) CAP_FIRST=H ;; i) CAP_FIRST=I ;;
			j) CAP_FIRST=J ;; k) CAP_FIRST=K ;; l) CAP_FIRST=L ;;
			m) CAP_FIRST=M ;; n) CAP_FIRST=N ;; o) CAP_FIRST=O ;;
			p) CAP_FIRST=P ;; q) CAP_FIRST=Q ;; r) CAP_FIRST=R ;;
			s) CAP_FIRST=S ;; t) CAP_FIRST=T ;; u) CAP_FIRST=U ;;
			v) CAP_FIRST=V ;; w) CAP_FIRST=W ;; x) CAP_FIRST=X ;;
			y) CAP_FIRST=Y ;; z) CAP_FIRST=Z ;;
		esac
		CAP_OUT="${CAP_OUT}${CAP_OUT:+ }${CAP_FIRST}${CAP_REST}"
	done
	printf "%s" "$CAP_OUT"
}

TBOX() {
	CMD=$1
	shift

	/opt/muos/bin/toybox "$CMD" "$@"
}

SET_VAR() {
	BASE=
	case "$1" in
		GLOBAL | global | CONFIG | config) BASE=$MUOS_CONF_GLOBAL ;;
		DEVICE | device) BASE=$MUOS_CONF_DEVICE ;;
		KIOSK | kiosk) BASE=$MUOS_CONF_KIOSK ;;
		SYSTEM | system) BASE=$MUOS_CONF_SYSTEM ;;
	esac

	[ -n "$BASE" ] || return 0

	TMP="${BASE}/${2}.tmp.$$"
	if ! { printf "%s" "$3" >"$TMP" && mv -f "$TMP" "$BASE/$2"; }; then
		rm -f "$TMP"
		return 1
	fi
}

GET_VAR() {
	BASE=
	case "$1" in
		GLOBAL | global | CONFIG | config) BASE=$MUOS_CONF_GLOBAL ;;
		DEVICE | device) BASE=$MUOS_CONF_DEVICE ;;
		KIOSK | kiosk) BASE=$MUOS_CONF_KIOSK ;;
		SYSTEM | system) BASE=$MUOS_CONF_SYSTEM ;;
	esac

	[ -n "$BASE" ] || return 0

	FILE="$BASE/$2"
	[ -r "$FILE" ] || return 0

	VAL=
	IFS= read -r VAL <"$FILE"

	VAL=${VAL%"$CR"}

	printf "%s" "$VAL"
}

DEL_VAR() {
	BASE=
	case "$1" in
		GLOBAL | global | CONFIG | config) BASE=$MUOS_CONF_GLOBAL ;;
		DEVICE | device) BASE=$MUOS_CONF_DEVICE ;;
		KIOSK | kiosk) BASE=$MUOS_CONF_KIOSK ;;
		SYSTEM | system) BASE=$MUOS_CONF_SYSTEM ;;
	esac

	[ -n "$BASE" ] || return 0

	DIR=$(dirname "$2")
	PATTERN=$(basename "$2")
	FULL_DIR="$BASE/$DIR"

	[ -d "$FULL_DIR" ] || return 0

	case "$PATTERN" in
		\**)
			EXCL_SPEC="${PATTERN#\*}"
			EXCLUDES=

			if [ -n "$EXCL_SPEC" ]; then
				OLD_IFS="$IFS"
				IFS='|'
				for TOKEN in $EXCL_SPEC; do
					EXCLUDES="$EXCLUDES ${TOKEN#!}"
				done
				IFS="$OLD_IFS"
			fi

			for FILE in "$FULL_DIR"/*; do
				[ -f "$FILE" ] || continue
				FNAME=$(basename "$FILE")

				SKIP=0
				for EXCL in $EXCLUDES; do
					[ "$FNAME" = "$EXCL" ] && SKIP=1 && break
				done

				[ "$SKIP" -eq 0 ] && rm -f "$FILE"
			done
			;;
		*)
			rm -f "$FULL_DIR/$PATTERN"
			;;
	esac
}

SETUP_STAGE_OVERLAY() {
	# Disable any stage overlay system for Console Mode, sorry not sorry!
	[ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ] && return 0

	[ -z "${MUX_LIB-}" ] && return 0
	STAGE_LIB="$MUX_LIB/libmustage.so"

	# LD_PRELOAD is space separated!
	case " ${LD_PRELOAD-} " in
		*" $STAGE_LIB "*) return 0 ;;
	esac

	if [ -n "${LD_PRELOAD-}" ]; then
		LD_PRELOAD="$STAGE_LIB $LD_PRELOAD"
	else
		LD_PRELOAD="$STAGE_LIB"
	fi

	export LD_PRELOAD
}

MIXER_INIT=
MIXER_CONTROL=
MIXER_DVOL=

RESET_MIXER() {
	if [ -z "$MIXER_INIT" ]; then
		MIXER_INIT=1
		MIXER_CONTROL=$(GET_VAR "device" "audio/control")
		MIXER_MAX=$(GET_VAR "device" "audio/max")
		[ -n "$MIXER_MAX" ] || MIXER_MAX=100

		case "$(GET_VAR "device" "board/name")" in
			rg-vita*) MIXER_DVOL=skip ;;
			mgx* | tui*) MIXER_DVOL=0 ;;
			*) MIXER_DVOL=$MIXER_MAX ;;
		esac
	fi

	[ -n "$MIXER_CONTROL" ] || return 1
	[ "$MIXER_DVOL" = "skip" ] && return 0

	amixer -c 0 sset "$MIXER_CONTROL" "${MIXER_DVOL}%" unmute >/dev/null 2>&1
	amixer set "Master" unmute >/dev/null 2>&1

	return 0
}

GET_SAVED_AUDIO_VOLUME() {
	SAVED_VOL=$(GET_VAR "config" "settings/general/volume")
	MIN_VOL=$(GET_VAR "device" "audio/min")
	MAX_VOL=$(GET_VAR "device" "audio/max")

	[ -n "$MIN_VOL" ] || MIN_VOL=0
	[ -n "$MAX_VOL" ] || MAX_VOL=100
	[ -n "$SAVED_VOL" ] || SAVED_VOL=$MIN_VOL

	[ "$SAVED_VOL" -lt "$MIN_VOL" ] && SAVED_VOL=$MIN_VOL
	[ "$SAVED_VOL" -gt "$MAX_VOL" ] && SAVED_VOL=$MAX_VOL

	printf "%s\n" "$SAVED_VOL"
}

SET_SAVED_AUDIO_VOLUME() {
	VALUE=$1

	MIN_VOL=$(GET_VAR "device" "audio/min")
	MAX_VOL=$(GET_VAR "device" "audio/max")

	[ -n "$MIN_VOL" ] || MIN_VOL=0
	[ -n "$MAX_VOL" ] || MAX_VOL=100
	[ -n "$VALUE" ] || VALUE=$MIN_VOL

	[ "$VALUE" -lt "$MIN_VOL" ] && VALUE=$MIN_VOL
	[ "$VALUE" -gt "$MAX_VOL" ] && VALUE=$MAX_VOL

	SET_VAR "config" "settings/general/volume" "$VALUE"

	return 0
}

RESTORE_AUDIO_VOLUME() {
	RESET_MIXER
	SAVED_VOL=$(GET_SAVED_AUDIO_VOLUME)

	for _ in 1 2 3 4 5 6 7 8 9 10; do
		wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && break
		sleep 0.5
	done

	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
	/opt/muos/script/device/audio.sh "$SAVED_VOL"
}

VOLUME_RAMP() {
	DIR="${1:-}"
	TARGET="${2:-}"
	STEP="${3:-5}"
	DELAY="${4:-0.01}"

	POWER_POP=$(GET_VAR "config" "settings/advanced/power_pop")
	[ -n "$POWER_POP" ] || POWER_POP=0

	[ "$POWER_POP" -eq 1 ] && return 0

	case "$DIR" in
		up | down) ;;
		*)
			printf "Usage: VOLUME_RAMP up|down [target%%] [step] [delay]\n" >&2
			return 1
			;;
	esac

	for _ in 1 2 3 4 5 6 7 8 9 10; do
		wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && break
		sleep 0.5
	done

	CUR_PCT=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/Volume:/{printf "%.0f", $2 * 100; exit}')
	[ -n "$CUR_PCT" ] || CUR_PCT=0

	case "$DIR" in
		up)
			[ -z "$TARGET" ] && TARGET=$(GET_SAVED_AUDIO_VOLUME)
			[ "$CUR_PCT" -gt "$TARGET" ] && CUR_PCT="$TARGET"

			while [ "$CUR_PCT" -lt "$TARGET" ]; do
				CUR_PCT=$((CUR_PCT + STEP))
				[ "$CUR_PCT" -gt "$TARGET" ] && CUR_PCT="$TARGET"

				wpctl set-volume @DEFAULT_AUDIO_SINK@ "${CUR_PCT}%" >/dev/null 2>&1
				sleep "$DELAY"
			done
			;;
		down)
			[ -n "$TARGET" ] || TARGET=0

			while [ "$CUR_PCT" -gt "$TARGET" ]; do
				CUR_PCT=$((CUR_PCT - STEP))
				[ "$CUR_PCT" -lt "$TARGET" ] && CUR_PCT="$TARGET"

				wpctl set-volume @DEFAULT_AUDIO_SINK@ "${CUR_PCT}%" >/dev/null 2>&1
				sleep "$DELAY"
			done

			[ "$TARGET" -eq 0 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 >/dev/null 2>&1
			;;
	esac

	return 0
}

SET_DEFAULT_GOVERNOR() {
	(
		DEF_GOV=$(GET_VAR "device" "cpu/default")
		GOV_PATH="$(GET_VAR "device" "cpu/governor")"
		printf "%s" "$DEF_GOV" >"$GOV_PATH"

		if [ "$DEF_GOV" = "ondemand" ]; then
			CPU_PATH=$(dirname "$GOV_PATH")

			# Detect differing kernel version layout
			if [ -d "$CPU_PATH/ondemand" ]; then
				OD_PATH="$CPU_PATH/ondemand"
			else
				OD_PATH="$CPU_PATH"
			fi

			MIN_PATH="$(GET_VAR "device" "cpu/min_freq")"
			MAX_PATH="$(GET_VAR "device" "cpu/max_freq")"

			[ -f "$MIN_PATH" ] && GET_VAR "device" "cpu/min_freq_default" >"$MIN_PATH"
			[ -f "$MAX_PATH" ] && GET_VAR "device" "cpu/max_freq_default" >"$MAX_PATH"

			[ -f "$OD_PATH/sampling_rate" ] && GET_VAR "device" "cpu/sampling_rate_default" >"$OD_PATH/sampling_rate"
			[ -f "$OD_PATH/up_threshold" ] && GET_VAR "device" "cpu/up_threshold_default" >"$OD_PATH/up_threshold"
			[ -f "$OD_PATH/sampling_down_factor" ] && GET_VAR "device" "cpu/sampling_down_factor_default" >"$OD_PATH/sampling_down_factor"
			[ -f "$OD_PATH/io_is_busy" ] && GET_VAR "device" "cpu/io_is_busy_default" >"$OD_PATH/io_is_busy"
		fi
	) &
}

ENSURE_REMOVED() {
	(
		P="$1"
		C=0

		while [ -e "$P" ] && [ "$C" -lt 10 ]; do
			rm -f -- "$P" 2>/dev/null

			[ -e "$P" ] || break

			C=$((C + 1))
			sleep 0.1
		done
	) &
}

GET_FRONTEND_PIDS() {
	pgrep -f 'muxfrontend|frontend\.sh' 2>/dev/null
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
		kill "-$SIG" "$PID" 2>/dev/null
	done
}

FRONTEND() {
	case "${1:-}" in
		stop)
			[ -n "$SAFE_QUIT" ] && { : >"$SAFE_QUIT" 2>/dev/null; }

			SIGNAL_FRONTEND USR1

			I=25
			while FRONTEND_RUNNING && [ "$I" -gt 0 ]; do
				sleep 0.2
				I=$((I - 1))
			done

			if FRONTEND_RUNNING; then
				SIGNAL_FRONTEND TERM

				J=15
				while FRONTEND_RUNNING && [ "$J" -gt 0 ]; do
					sleep 0.2
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

			if [ -n "${2:-}" ]; then
				setsid -f /opt/muos/script/mux/frontend.sh "$2" </dev/null >/dev/null 2>&1
			else
				setsid -f /opt/muos/script/mux/frontend.sh </dev/null >/dev/null 2>&1
			fi
			;;
		restart)
			FRONTEND stop

			if [ -n "${2:-}" ]; then
				FRONTEND start "$2"
			else
				FRONTEND start
			fi
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
			rm -f "$IDLE_STATE" 2>/dev/null
			while pgrep -f 'muhotkey|hotkey\.sh' >/dev/null; do
				killall -9 muhotkey hotkey.sh
				sleep 1
			done
			;;
		start)
			pgrep -f muhotkey >/dev/null && return 0
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

BATTERY() {
	case "$1" in
		stop)
			while pgrep -f mubattery >/dev/null; do
				killall -9 mubattery
				sleep 1
			done
			;;
		start)
			pgrep -f mubattery >/dev/null && return 0
			setsid -f /opt/muos/frontend/mubattery </dev/null >/dev/null 2>&1
			;;
		restart)
			BATTERY stop
			BATTERY start
			;;
		*)
			printf "Usage: BATTERY start | stop | restart\n"
			return 1
			;;
	esac
}

CAFFEINE() {
	DRINK="$MUOS_RUN_DIR/caffeine"

	case "${1:-}" in
		on)
			: >"$DRINK"
			;;
		off)
			rm -f "$DRINK" 2>/dev/null
			;;
		toggle)
			if [ -f "$DRINK" ]; then
				rm -f "$DRINK" 2>/dev/null
			else
				: >"$DRINK"
			fi
			;;
		status)
			[ -f "$DRINK" ] && return 0 || return 1
			;;
		*)
			printf "Usage: CAFFEINE on | off | toggle | status\n"
			return 1
			;;
	esac
}

MUXCTL() {
	case "${1:-}" in
		stop)
			HOTKEY stop
			FRONTEND stop
			BATTERY stop
			;;
		start)
			HOTKEY start

			if [ -n "${2:-}" ]; then
				FRONTEND start "$2"
			else
				FRONTEND start
			fi

			BATTERY start
			;;
		restart)
			MUXCTL stop

			if [ -n "${2:-}" ]; then
				MUXCTL start "$2"
			else
				MUXCTL start
			fi
			;;
		*)
			printf "Usage: MUXCTL start [module] | stop | restart [module]\n"
			return 1
			;;
	esac
}

MESSAGE() {
	case "$1" in
		stop)
			if pgrep -f "$MESSAGE_EXEC" >/dev/null; then
				[ -f "$MESSAGE_TEXT" ] && rm -f "$MESSAGE_TEXT" "$MESSAGE_PROG"
				pkill -9 -f "$MESSAGE_EXEC"
			fi
			;;
		start)
			pgrep -f "$MESSAGE_EXEC" >/dev/null && return 0
			[ ! -f "$MESSAGE_TEXT" ] && touch "$MESSAGE_TEXT"
			setsid -f "$MESSAGE_EXEC" 0 "" -l "$MESSAGE_TEXT" </dev/null >/dev/null 2>&1
			;;
		restart)
			MESSAGE stop
			MESSAGE start
			;;
		*)
			printf "Usage: MESSAGE start | stop | restart\n"
			return 1
			;;
	esac
}

SHOW_MESSAGE() {
	[ ! -f "$MESSAGE_TEXT" ] && MESSAGE start

	if pgrep -f "$MESSAGE_EXEC" >/dev/null; then
		echo "$1" >"$MESSAGE_PROG"
		echo "$2" >"$MESSAGE_TEXT"
	fi
}

EXEC_MUX() {
	if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
		while [ ! -f "$MUOS_RUN_DIR/hdmi_mode" ]; do sleep 0.05; done
	fi

	[ -f "$SAFE_QUIT" ] && rm -f "$SAFE_QUIT"

	GOBACK="$1"
	MODULE="$2"
	shift

	[ -n "$GOBACK" ] && echo "$GOBACK" >"$ACT_GO"

	RESTORE_AUDIO_VOLUME

	SET_VAR "system" "foreground_process" "$MODULE"
	"/opt/muos/frontend/$MODULE" "$@"

	while [ ! -f "$SAFE_QUIT" ]; do sleep 0.05; done
}

# Prints current system uptime in hundredths of a second. Unlike date or
# EPOCHREALTIME, this won't decrease if the system clock is set back, so it can
# be used to measure an interval of real time.
UPTIME() {
	cut -d ' ' -f 1 /proc/uptime
}

DELETE_CRUFT() {
	(
		[ "$1" ] || return

		find "$1" -type d \( \
			-name 'System Volume Information' -o \
			-name '.Trashes' -o \
			-name '.Spotlight' -o \
			-name '.fseventsd' \
			\) -exec rm -rf -- {} +

		find "$1" -type f \( \
			-name '._*' -o \
			-name '.DS_Store' -o \
			-name 'desktop.ini' -o \
			-name 'Thumbs.db' -o \
			-name '.DStore' -o \
			-name '.gitkeep' \
			\) -exec rm -f -- {} +
	) &
}

PARSE_INI() {
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"

	sed -n "/^\[$SECTION\]/ { :l /^${KEY}[ ]*=[ ]*/ { s/^[^=]*=[ ]*//; p; q; }; n; b l; }" "${INI_FILE}"
}

GET_DEBUG() {
	DEBUG_MODE=0

	[ -r "$MUOS_CONF_SYSTEM/debug_mode" ] && {
		IFS= read -r DEBUG_MODE <"$MUOS_CONF_SYSTEM/debug_mode" 2>/dev/null
	}

	DEBUG_MODE=${DEBUG_MODE%"$CR"}

	case "$DEBUG_MODE" in
		''|*[!0-9]*)
			DEBUG_MODE=0
			;;
	esac

	printf "%d" "$DEBUG_MODE"
}

if [ "$(GET_DEBUG)" -gt 0 ]; then
	LOG_INFO() {
		"$MUOS_LOG_BIN" info "$@"
	}

	LOG_WARN() {
		"$MUOS_LOG_BIN" warn "$@"
	}

	LOG_ERROR() {
		"$MUOS_LOG_BIN" error "$@"
	}

	LOG_SUCCESS() {
		"$MUOS_LOG_BIN" success "$@"
	}

	LOG_DEBUG() {
		"$MUOS_LOG_BIN" debug "$@"
	}
else
	LOG_INFO() { :; }
	LOG_WARN() { :; }
	LOG_ERROR() { :; }
	LOG_SUCCESS() { :; }
	LOG_DEBUG() { :; }
fi

CRITICAL_FAILURE() {
	case "$1" in
		mount) MESSAGE=$(printf "Mount Failure\n\n%s%s" "$1" "$2") ;;
		udev) MESSAGE=$(printf "Critical Failure\n\nFailed to initialise udev!") ;;
		*) MESSAGE=$(printf "Critical Failure\n\nAn unknown error occurred!") ;;
	esac

	/opt/muos/frontend/muxmessage 0 "$MESSAGE"
	sleep 10
	/opt/muos/script/system/halt.sh poweroff
}

RUMBLE() {
	if [ -n "$(GET_VAR "device" "board/rumble")" ]; then
		case "$(GET_VAR "device" "board/name")" in
			rk*)
				echo 1 >"$1"
				sleep "$2"
				echo 1000000 >"$1"
				;;
			rg-vita*)
				echo 0 >"$1"
				sleep "$2"
				echo 1 >"$1"
				;;
			*)
				echo 1 >"$1"
				sleep "$2"
				echo 0 >"$1"
				;;
		esac
	fi
}

FB_SWITCH() {
	FB_WIDTH="${1}"
	FB_HEIGHT="${2}"
	FB_DEPTH="${3}"

	for FB_MODE in screen mux; do
		SET_VAR "device" "${FB_MODE}/width" "${FB_WIDTH}"
		SET_VAR "device" "${FB_MODE}/height" "${FB_HEIGHT}"
	done

	HDMI_NODE="$(GET_VAR "device" "screen/hdmi")"
	FB_ACTUAL_WIDTH="${FB_WIDTH}"
	FB_ACTUAL_HEIGHT="${FB_HEIGHT}"

	if [ "$(GET_VAR "device" "board/name")" = "rg28xx-h" ]; then
		HDMI_NODE_VAL=0
		if [ -r "${HDMI_NODE}" ]; then
			IFS= read -r HDMI_NODE_VAL <"${HDMI_NODE}"
		fi
		if [ "${HDMI_NODE_VAL}" = "0" ]; then
			FB_ACTUAL_WIDTH="${FB_HEIGHT}"
			FB_ACTUAL_HEIGHT="${FB_WIDTH}"
		fi
	fi

	/opt/muos/frontend/mufbset -w "${FB_ACTUAL_WIDTH}" -h "${FB_ACTUAL_HEIGHT}" -d "${FB_DEPTH}"
}

HDMI_SWITCH() {
	HS_RES="$(GET_VAR "config" "settings/hdmi/resolution")"
	HD_DEP=32

	case "${HS_RES}" in
		0 | 1)
			HS_WIDTH=720
			HS_HEIGHT=480
			;; # 480i / 576i  (720-stride interlaced)
		2)
			HS_WIDTH=720
			HS_HEIGHT=480
			;; # 480p
		3)
			HS_WIDTH=720
			HS_HEIGHT=576
			;; # 576p
		4 | 5)
			HS_WIDTH=1280
			HS_HEIGHT=720
			;; # 720p (50 or 60 Hz)
		6 | 7)
			HS_WIDTH=1920
			HS_HEIGHT=1080
			;; # 1080i (50 or 60 Hz)
		8 | 9 | 10)
			HS_WIDTH=1920
			HS_HEIGHT=1080
			;; # 1080p (24, 50, or 60 Hz)
		*)
			# Unknown index - fall back to internal panel size
			HS_WIDTH="$(GET_VAR "device" "screen/internal/width")"
			HS_HEIGHT="$(GET_VAR "device" "screen/internal/height")"
			;;
	esac

	SET_VAR "device" "screen/external/width" "${HS_WIDTH}"
	SET_VAR "device" "screen/external/height" "${HS_HEIGHT}"

	FB_SWITCH "${HS_WIDTH}" "${HS_HEIGHT}" "${HD_DEP}"
}

# Normal mode is stating that the factory reset routine is complete
# and the device can act as it's supposed to, seems like some users
# are "sleeping" their devices during the factory reset process.
IS_NORMAL_MODE() {
	[ "$(GET_VAR "config" "boot/factory_reset")" -eq 0 ]
}

# Handheld mode states stating whether or not the Console Mode (HDMI)
# is preset and active.  We don't want specific hotkeys to run if we
# are in currently in Console Mode.
IS_HANDHELD_MODE() {
	[ "$(GET_VAR "config" "boot/device_mode")" -eq 0 ]
}

DISPLAY_SYSFS_BACKLIGHT() {
	[ -n "${BL_PATH_CACHE-}" ] && {
		printf "%s\n" "$BL_PATH_CACHE"
		return 0
	}
	for B in /sys/class/backlight/*; do
		[ -f "$B/brightness" ] && {
			BL_PATH_CACHE=$B
			printf "%s\n" "$B"
			return 0
		}
	done
	return 1
}

# Writes a setting value to the display driver.
# Typically used for brightness on most devices but has
# HDMI mode support for those who use it, unfortunately
# Usage: DISPLAY_WRITE NAME COMMAND PARAM
DISPLAY_WRITE() {
	DW_NAME="${1}"
	DW_CMD="${2}"
	DW_PARAM="${3}"

	# Prefer sysfs backlight if available
	if BL_PATH=$(DISPLAY_SYSFS_BACKLIGHT); then
		printf "%s" "$DW_PARAM" >"$BL_PATH/brightness"
		return
	fi

	# Fallback to dispdbg parameters
	case "$(GET_VAR "device" "board/name")" in
		rg* | mgx* | tui*)
			printf "%s" "${DW_NAME}" >/sys/kernel/debug/dispdbg/name
			printf "%s" "${DW_CMD}" >/sys/kernel/debug/dispdbg/command
			printf "%s" "${DW_PARAM}" >/sys/kernel/debug/dispdbg/param
			printf "1\n" >/sys/kernel/debug/dispdbg/start
			;;
	esac
}

# Reads and prints a setting value from the display driver.
# Just like the above function it is mainly for brightness
# but can also be used for HDMI functionality...
# Usage: DISPLAY_READ NAME COMMAND
DISPLAY_READ() {
	DR_NAME="${1}"
	DR_CMD="${2}"

	if BL_PATH=$(DISPLAY_SYSFS_BACKLIGHT); then
		IFS= read -r BL_VAL <"$BL_PATH/brightness" && printf "%s\n" "$BL_VAL"
		return
	fi

	case "$(GET_VAR "device" "board/name")" in
		rg* | mgx* | tui*)
			printf "%s" "${DR_NAME}" >/sys/kernel/debug/dispdbg/name
			printf "%s" "${DR_CMD}" >/sys/kernel/debug/dispdbg/command
			printf "1\n" >/sys/kernel/debug/dispdbg/start
			cat /sys/kernel/debug/dispdbg/info
			;;
	esac
}

DISPLAY_IDLE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && amixer set "Master" mute

	[ "$(DISPLAY_READ disp0 getbl)" -gt 10 ] && DISPLAY_WRITE disp0 setbl 10

	LED_CONTROL_CHANGE off

	printf 1 >"$IDLE_STATE"

	: >"$IS_IDLE"
}

DISPLAY_ACTIVE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && amixer set "Master" unmute

	DISPLAY_WRITE disp0 setbl "$(GET_VAR "config" "settings/general/brightness")"

	LED_CONTROL_CHANGE restore

	printf 0 >"$IDLE_STATE"

	[ -e "$IS_IDLE" ] && rm -f "$IS_IDLE"
}

LCD_DISABLE() {
	if [ "$(GET_VAR "config" "settings/advanced/disp_suspend")" -eq 1 ]; then
		sleep 0.5
		DISPLAY_WRITE lcd0 disable 0
		sleep 0.5
	fi
}

LCD_ENABLE() {
	if [ "$(GET_VAR "config" "settings/advanced/disp_suspend")" -eq 1 ]; then
		sleep 0.5
		DISPLAY_WRITE lcd0 enable 0
		sleep 0.5
	fi
}

SETUP_GL4ES() {
	GL4ES_LIB="/usr/lib/gl4es"

	if [ -d "$GL4ES_LIB" ]; then
		case ":${LD_LIBRARY_PATH-}:" in
			*":$GL4ES_LIB:"*) ;;
			*) LD_LIBRARY_PATH="$GL4ES_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
		esac
		export LD_LIBRARY_PATH
	fi
}

SETUP_SDL_ENVIRONMENT() {
	REQ_STYLE=""
	SKIP_BLITTER=0

	for A in "$@"; do
		case "$A" in
			retro | modern) REQ_STYLE="$A" ;; # Optional priority override: $1 = retro | modern
			skip_blitter) SKIP_BLITTER=1 ;; # Used primarily for external ScummVM at the moment
		esac
	done

	GCDB_DEFAULT="/usr/lib/gamecontrollerdb.txt"
	GCDB_STORE="$MUOS_SHARE_DIR/info/gamecontrollerdb"

	# Decide controller DB (priority: arg -> /tmp/con_go -> default)
	case "$REQ_STYLE" in
		modern) GCDB_FILE="$GCDB_STORE/modern.txt" ;;
		retro) GCDB_FILE="$GCDB_STORE/retro.txt" ;;
		*)
			CON_GO="/tmp/con_go"
			if [ -e "$CON_GO" ]; then
				IFS= read -r SEL <"$CON_GO"
				case "$SEL" in
					# honour "system" - otherwise use whatever was selected from content...
					system)
						case "$(GET_VAR "config" "settings/remap/layout")" in
							1) GCDB_FILE="$GCDB_STORE/modern.txt" ;;
							*) GCDB_FILE="$GCDB_STORE/retro.txt" ;;
						esac
						;;
					*) GCDB_FILE="$GCDB_STORE/$SEL.txt" ;;
				esac
			else
				GCDB_FILE="$GCDB_STORE/retro.txt"
			fi
			;;
	esac

	# Remove and relink controller DB
	rm -f "$GCDB_DEFAULT"
	ln -sf "$GCDB_FILE" "$GCDB_DEFAULT"

	# Set both the SDL controller file and configuration
	SDL_GAMECONTROLLERCONFIG_FILE="$GCDB_FILE"
	SDL_CACHE="/tmp/sdl_gc_${GCDB_FILE##*/}"
	if [ -f "$SDL_CACHE" ]; then
		SDL_GAMECONTROLLERCONFIG=$(cat "$SDL_CACHE")
	else
		SDL_GAMECONTROLLERCONFIG=$(grep "$(GET_VAR "device" "sdl/name")" "$GCDB_FILE")
		printf '%s\n' "$SDL_GAMECONTROLLERCONFIG" >"$SDL_CACHE"
	fi

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

	SETUP_GL4ES
}

SETUP_APP() {
	printf "app\n" >"/tmp/act_go"

	GOV_GO="/tmp/gov_go"
	[ -e "$GOV_GO" ] && cp -f "$GOV_GO" "$(GET_VAR "device" "cpu/governor")"

	HOME="$(GET_VAR "device" "board/home")"
	export HOME

	XDG_CONFIG_HOME="$HOME/.config"
	export XDG_CONFIG_HOME

	SET_VAR "system" "foreground_process" "$1"

	if [ -n "${2:-}" ]; then
		SETUP_SDL_ENVIRONMENT "$2"
	else
		SETUP_SDL_ENVIRONMENT
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
	RA_DEV_CONF="$DEVICE_CONTROL_DIR/retroarch.device.cfg"
	CON_GO="/tmp/con_go"
	IS_SWAP=0

	DO_SWAP() {
		/opt/muos/script/mux/swap_abxy.sh "$RA_DEV_CONF"
		IS_SWAP=1
	}

	if [ -e "$CON_GO" ]; then
		IFS= read -r CON_VAL <"$CON_GO"
		case "$CON_VAL" in
			modern) DO_SWAP ;;
			retro) ;;
			*) [ "$(GET_VAR "config" "settings/remap/layout")" -eq 1 ] && DO_SWAP ;;
		esac
	fi

	printf "%s\n" "$IS_SWAP"
}

CONFIGURE_RETROARCH() {
	RA_CONF="$MUOS_SHARE_DIR/info/config/retroarch.cfg"
	RA_DEF="$MUOS_SHARE_DIR/emulator/retroarch/retroarch.default.cfg"
	RA_CONTROL="$DEVICE_CONTROL_DIR/retroarch"

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
			printf "rgui_aspect_ratio = \"%s\"\n" "1"
		else
			printf "rgui_aspect_ratio = \"%s\"\n" "0"
		fi
	) >"$RA_CONTROL.resolution.cfg"

	# Modify the RetroArch threaded video option based on content settings
	RAC_GO="/tmp/rac_go"
	if [ -f "$RAC_GO" ]; then
		IFS= read -r RAC_VAL <"$RAC_GO"
		sed -i '/^video_threaded = /d' "$RA_CONF"
		printf 'video_threaded = "%s"\n' "$RAC_VAL" >>"$RA_CONF"
	fi

	# Include default button mappings from retroarch.device.cfg. Settings in the
	# retroarch.cfg will take precedence. Modified settings will save to the main
	# retroarch.cfg, not the included retroarch.device.cfg file.
	RA_TYPES="device resolution"

	# Create a temporary config file with all matching lines from the original config,
	# excluding any existing include lines for the given RetroArch types in the var.
	TMP_RA_CONF=$(mktemp) || return 1
	(
		trap 'rm -f "$TMP_RA_CONF"' EXIT

		# Exclude any existing include lines for the given RetroArch types.
		for TYPE in $RA_TYPES; do
			printf '#include "%s.%s.cfg"\n' "$RA_CONTROL" "$TYPE"
		done | grep -vFf - "$RA_CONF" >"$TMP_RA_CONF"

		# Append the required include lines so they are always present.
		for TYPE in $RA_TYPES; do
			printf '#include "%s.%s.cfg"\n' "$RA_CONTROL" "$TYPE" >>"$TMP_RA_CONF"
		done

		# Replace the original config with the modified version.
		mv "$TMP_RA_CONF" "$RA_CONF"
	) || {
		rm -f "$TMP_RA_CONF"
		return 1
	}

	# Set kiosk mode value based on current configuration.
	case "$(GET_VAR "kiosk" "content/retroarch")" in
		1) KIOSK_MODE=true ;;
		*) KIOSK_MODE=false ;;
	esac
	sed -i "s/^kiosk_mode_enable = \".*\"$/kiosk_mode_enable = \"$KIOSK_MODE\"/" "$RA_CONF"

	# Re-define the symlink to current configuration.
	HOME_CFG="$(GET_VAR "device" "board/home")/.config"

	# Purge it just in case it was created by something else!
	rm -rf "$HOME_CFG/retroarch"
	ln -s "$MUOS_SHARE_DIR/emulator/retroarch" "$HOME_CFG/retroarch"
	rm -f "$MUOS_SHARE_DIR/emulator/retroarch/retroarch.cfg"
	ln -s "$MUOS_SHARE_DIR/info/config/retroarch.cfg" "$MUOS_SHARE_DIR/emulator/retroarch/retroarch.cfg"

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
	printf '%s\n' "$EXTRA_ARGS"
}

CHECK_EXIST() {
	[ -w "$2" ] || return 0
	GET_VAR "config" "$1" >"$2"
}

KERNEL_TUNING() {
	CHECK_EXIST "danger/vmswap" "/proc/sys/vm/swappiness"
	CHECK_EXIST "danger/dirty_ratio" "/proc/sys/vm/dirty_ratio"
	CHECK_EXIST "danger/dirty_back_ratio" "/proc/sys/vm/dirty_background_ratio"
	CHECK_EXIST "danger/cache_pressure" "/proc/sys/vm/vfs_cache_pressure"

	CHECK_EXIST "danger/nomerges" "/sys/block/$1/queue/nomerges"
	CHECK_EXIST "danger/nr_requests" "/sys/block/$1/queue/nr_requests"
	CHECK_EXIST "danger/iostats" "/sys/block/$1/queue/iostats"

	CHECK_EXIST "danger/idle_flush" "/proc/sys/vm/laptop_mode"
	CHECK_EXIST "danger/page_cluster" "/proc/sys/vm/page-cluster"
	CHECK_EXIST "danger/child_first" "/proc/sys/kernel/sched_child_runs_first"
	CHECK_EXIST "danger/time_slice" "/proc/sys/kernel/sched_rr_timeslice_ms"
	CHECK_EXIST "danger/tune_scale" "/proc/sys/kernel/sched_tunable_scaling"

	if [ -b "/dev/$1" ]; then
		blockdev --setra "$(GET_VAR "config" "danger/read_ahead")" "/dev/$1"
	fi
}

LED_CONTROL_CHANGE() {
	[ "$(GET_VAR "device" "led/rgb")" -eq 1 ] && "$MUOS_RGB_BIN" "$1"
}

DEVICE_THEME_FIX() {
	ROLE="$1"
	IMAGE="$2"

	case "$(GET_VAR "device" "board/name")" in
		rg28xx-h)
			convert "$IMAGE" -rotate 270 "$IMAGE"
			printf "Rotated '%s' image: %s\n" "$ROLE" "$IMAGE"
			;;
	esac
}

THEME_PNG_IMAGE() {
	ROLE="$1"
	SRC="$2"
	OUT="$3"

	BACKGROUND_COLOUR="000000"
	BACKGROUND_GRADIENT_COLOUR="000000"
	PNG_RECOLOUR="FFFFFF"
	PNG_RECOLOUR_ALPHA=0

	NORMALISE_HEX() {
		VAL="${1#\#}"

		case "$VAL" in
			[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
				printf "%s" "$VAL"
				return 0
				;;
		esac

		return 1
	}

	CLAMP_ALPHA() {
		VAL="$1"

		case "$VAL" in
			'' | *[!0-9]*) VAL=0 ;;
		esac

		[ "$VAL" -lt 0 ] && VAL=0
		[ "$VAL" -gt 255 ] && VAL=255

		printf "%s" "$VAL"
	}

	JSONPATH="$THEME_DIR/${ROLE}.json"

	if [ -e "$THEME_DIR/active.txt" ]; then
		read -r THEME_ALTERNATE <"$THEME_DIR/active.txt"
		printf "Theme Alternate: %s\n" "$THEME_ALTERNATE"
		ALT_JSON="$THEME_DIR/alternate/${THEME_ALTERNATE}_${ROLE}.json"
		[ -e "$ALT_JSON" ] && JSONPATH="$ALT_JSON"
	fi

	if [ -e "$JSONPATH" ]; then
		printf "Found '%s' JSON: %s\n" "$ROLE" "$JSONPATH"

		# Single jq invocation pulling all four values, tab-separated
		JQ_OUT=$(jq -r '[.background_colour, .background_gradient_colour, .png_recolour, .png_recolour_alpha] | map(. // "") | @tsv' "$JSONPATH")
		IFS='	' read -r JQ_BG JQ_BGG JQ_PR JQ_PRA <<EOF
$JQ_OUT
EOF

		if [ -n "$JQ_BG" ] && HEX=$(NORMALISE_HEX "$JQ_BG"); then
			BACKGROUND_COLOUR="$HEX"
		fi

		if [ -n "$JQ_BGG" ] && HEX=$(NORMALISE_HEX "$JQ_BGG"); then
			BACKGROUND_GRADIENT_COLOUR="$HEX"
		else
			BACKGROUND_GRADIENT_COLOUR="$BACKGROUND_COLOUR"
		fi

		if [ -n "$JQ_PR" ] && HEX=$(NORMALISE_HEX "$JQ_PR"); then
			PNG_RECOLOUR="$HEX"
		fi

		if [ -n "$JQ_PRA" ]; then
			RAW_ALPHA=$(CLAMP_ALPHA "$JQ_PRA")
			PNG_RECOLOUR_ALPHA=$((RAW_ALPHA * 100 / 255))
		fi
	else
		printf "No '%s' JSON found... using defaults!\n" "$ROLE"
	fi

	[ -z "$BACKGROUND_GRADIENT_COLOUR" ] && BACKGROUND_GRADIENT_COLOUR="$BACKGROUND_COLOUR"

	if [ "$PNG_RECOLOUR_ALPHA" -le 0 ]; then
		PNG_RECOLOUR=""
		PNG_RECOLOUR_ALPHA=0
	fi

	printf "Creating '%s' image:\n" "$ROLE"
	printf "SRC: %s\n" "$SRC"
	printf "OUT: %s\n" "$OUT"
	printf "BACKGROUND_COLOUR: %s\n" "$BACKGROUND_COLOUR"
	printf "BACKGROUND_GRADIENT_COLOUR: %s\n" "$BACKGROUND_GRADIENT_COLOUR"
	printf "PNG_RECOLOUR: %s\n" "$PNG_RECOLOUR"
	printf "PNG_RECOLOUR_ALPHA: %s\n" "$PNG_RECOLOUR_ALPHA"

	TMP_BG="/tmp/${ROLE}_bg_$$.png"
	TMP_FG="/tmp/${ROLE}_fg_$$.png"
	TMP_OUT="/tmp/${ROLE}_out_$$.png"

	rm -f "$TMP_BG" "$TMP_FG" "$TMP_OUT"

	if [ "$BACKGROUND_COLOUR" = "$BACKGROUND_GRADIENT_COLOUR" ]; then
		magick -size "${DEVICE_W}x${DEVICE_H}" xc:"#${BACKGROUND_COLOUR}" "$TMP_BG"
	else
		magick -size 1x"${DEVICE_H}" gradient:"#${BACKGROUND_COLOUR}-#${BACKGROUND_GRADIENT_COLOUR}" -resize "${DEVICE_W}x${DEVICE_H}!" "$TMP_BG"
	fi

	if [ "$PNG_RECOLOUR_ALPHA" -gt 0 ]; then
		magick "$SRC" -fill "#${PNG_RECOLOUR}" -colorize "$PNG_RECOLOUR_ALPHA" "$TMP_FG"
	else
		cp -f "$SRC" "$TMP_FG"
	fi

	magick "$TMP_FG" "$TMP_BG" -compose Dst_Over -composite -alpha off BMP3:"$TMP_OUT"
	case "$OUT" in
		*.bmp | *.BMP) magick "$TMP_OUT" BMP3:"$OUT" ;;
		*) mv -f "$TMP_OUT" "$OUT" ;;
	esac

	rm -f "$TMP_BG" "$TMP_FG" "$TMP_OUT"
}

RESOLVE_ROLE_IMAGE() {
	ROLE="$1"
	OUT="$2"

	for BASE in "$THEME_DIR/$RES_DIR/image/$ROLE" "$THEME_DIR/image/$ROLE"; do
		printf "Checking path: %s\n" "$BASE.png"
		if [ -f "$BASE.png" ]; then
			printf "Found %s PNG: %s\n" "$ROLE" "$BASE.png"
			THEME_PNG_IMAGE "$ROLE" "$BASE.png" "$OUT"
			return 0
		fi

		printf "Checking path: %s\n" "$BASE.bmp"
		if [ -f "$BASE.bmp" ]; then
			printf "Found %s BMP: %s\n" "$ROLE" "$BASE.bmp"
			cp -f "$BASE.bmp" "$OUT"
			return 0
		fi
	done

	return 1
}

UPDATE_IMAGE_ROLE() {
	ROLE="$1" # bootlogo, charge, etc
	DEST="$2" # relative to boot mount

	OUT="$BOOT_MOUNT/$DEST"
	DIR=$(dirname "$OUT")

	mkdir -p "$DIR"

	if ! RESOLVE_ROLE_IMAGE "$ROLE" "$OUT"; then
		printf "No theme '%s' image found\n" "$ROLE"
		return 1
	fi

	DEVICE_THEME_FIX "$ROLE" "$OUT"
	return 0
}

UPDATE_BOOTLOGO() {
	rm -f "/tmp/btl_go"

	BOOT_MOUNT=$(GET_VAR "device" "storage/boot/mount")
	[ -n "$BOOT_MOUNT" ] || return 1

	DEVICE_W=$(GET_VAR "device" "screen/internal/width")
	DEVICE_H=$(GET_VAR "device" "screen/internal/height")

	[ -n "$DEVICE_W" ] || DEVICE_W=$(GET_VAR "device" "screen/width")
	[ -n "$DEVICE_H" ] || DEVICE_H=$(GET_VAR "device" "screen/height")
	[ -n "$DEVICE_W" ] || return 1
	[ -n "$DEVICE_H" ] || return 1

	ACTIVE=$(GET_VAR "config" "theme/active")
	THEME_DIR="$MUOS_STORE_DIR/theme/$ACTIVE"
	RES_DIR="${DEVICE_W}x${DEVICE_H}"

	if ! UPDATE_IMAGE_ROLE "bootlogo" "bootlogo.bmp"; then
		cp -f "$MUOS_SHARE_DIR/bootlogo/${DEVICE_W}x${DEVICE_H}/bootlogo.bmp" "$BOOT_MOUNT/bootlogo.bmp"
		DEVICE_THEME_FIX "bootlogo" "$BOOT_MOUNT/bootlogo.bmp"
	fi

	if ! UPDATE_IMAGE_ROLE "charge" "bat/battery_charge.bmp"; then
		mkdir -p "$BOOT_MOUNT/bat"
		cp -f "$BOOT_MOUNT/bootlogo.bmp" "$BOOT_MOUNT/bat/battery_charge.bmp"
	fi

	return 0
}

SHOW_SPLASH() {
	ROLE="${1:-load}"

	SPLASH_BIN="/opt/muos/frontend/musplash"
	[ -x "$SPLASH_BIN" ] || return 1

	case "$ROLE" in
		bootlogo | shutdown | reboot | reset | load) ;;
		clear) "$SPLASH_BIN" -c && return 0 ;;
		*) return 1 ;;
	esac

	DEVICE_W=$(GET_VAR "device" "screen/internal/width")
	DEVICE_H=$(GET_VAR "device" "screen/internal/height")

	[ -n "$DEVICE_W" ] || DEVICE_W=$(GET_VAR "device" "screen/width")
	[ -n "$DEVICE_H" ] || DEVICE_H=$(GET_VAR "device" "screen/height")
	[ -n "$DEVICE_W" ] || return 1
	[ -n "$DEVICE_H" ] || return 1

	ACTIVE=$(GET_VAR "config" "theme/active")
	THEME_DIR="$MUOS_STORE_DIR/theme/$ACTIVE"
	RES_DIR="${DEVICE_W}x${DEVICE_H}"

	# TODO: Add splash scale to advanced options
	SCALE=$(GET_VAR "config" "settings/advanced/splash_scale")
	case "$SCALE" in
		0 | 1 | 2 | 3) ;;
		*) SCALE=0 ;;
	esac

	case "$(GET_VAR "device" "board/name")" in
		rg28xx-h | rg-vita-pro) ROTATE=270 ;;
		*) ROTATE=0 ;;
	esac

	BACKGROUND_COLOUR="000000"
	BACKGROUND_GRADIENT_COLOUR="000000"
	PNG_RECOLOUR="FFFFFF"
	PNG_RECOLOUR_ALPHA=0

	NORMALISE_HEX() {
		VAL="${1#\#}"

		case "$VAL" in
			[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
				printf "%s" "$VAL"
				return 0
				;;
		esac

		return 1
	}

	CLAMP_ALPHA() {
		VAL="$1"

		case "$VAL" in
			'' | *[!0-9]*) VAL=0 ;;
		esac

		[ "$VAL" -lt 0 ] && VAL=0
		[ "$VAL" -gt 255 ] && VAL=255

		printf "%s" "$VAL"
	}

	JSONPATH="$THEME_DIR/${ROLE}.json"

	if [ -e "$THEME_DIR/active.txt" ]; then
		read -r THEME_ALTERNATE <"$THEME_DIR/active.txt"
		ALT_JSON="$THEME_DIR/alternate/${THEME_ALTERNATE}_${ROLE}.json"
		[ -e "$ALT_JSON" ] && JSONPATH="$ALT_JSON"
	fi

	if [ -e "$JSONPATH" ]; then
		# Single jq invocation pulling all four values, tab-separated
		JQ_OUT=$(jq -r '[.background_colour, .background_gradient_colour, .png_recolour, .png_recolour_alpha] | map(. // "") | @tsv' "$JSONPATH")
		IFS='	' read -r JQ_BG JQ_BGG JQ_PR JQ_PRA <<EOF
$JQ_OUT
EOF

		if [ -n "$JQ_BG" ] && HEX=$(NORMALISE_HEX "$JQ_BG"); then
			BACKGROUND_COLOUR="$HEX"
		fi

		if [ -n "$JQ_BGG" ] && HEX=$(NORMALISE_HEX "$JQ_BGG"); then
			BACKGROUND_GRADIENT_COLOUR="$HEX"
		else
			BACKGROUND_GRADIENT_COLOUR="$BACKGROUND_COLOUR"
		fi

		if [ -n "$JQ_PR" ] && HEX=$(NORMALISE_HEX "$JQ_PR"); then
			PNG_RECOLOUR="$HEX"
		fi

		if [ -n "$JQ_PRA" ]; then
			RAW_ALPHA=$(CLAMP_ALPHA "$JQ_PRA")
			PNG_RECOLOUR_ALPHA=$((RAW_ALPHA * 100 / 255))
		fi
	fi

	[ -z "$BACKGROUND_GRADIENT_COLOUR" ] && BACKGROUND_GRADIENT_COLOUR="$BACKGROUND_COLOUR"

	set -- -r "$ROTATE" -s "$SCALE" -g "${BACKGROUND_COLOUR}:${BACKGROUND_GRADIENT_COLOUR}"

	if [ "$PNG_RECOLOUR_ALPHA" -gt 0 ]; then
		set -- "$@" -t "$PNG_RECOLOUR" -a "$PNG_RECOLOUR_ALPHA"
	fi

	FBCON_DISABLE

	CURR_LANG="$(GET_VAR "config" "settings/general/language")"

	for SRC in \
		"$THEME_DIR/$RES_DIR/image/$CURR_LANG/$ROLE.png" \
		"$THEME_DIR/$RES_DIR/image/$ROLE.png" \
		"$THEME_DIR/image/$CURR_LANG/$ROLE.png" \
		"$THEME_DIR/image/$ROLE.png" \
		"$MUOS_SHARE_DIR/media/splash/$RES_DIR/$CURR_LANG/$ROLE.png" \
		"$MUOS_SHARE_DIR/media/splash/$RES_DIR/$ROLE.png" \
		"$MUOS_SHARE_DIR/media/splash/$ROLE.png"; do
		if [ -f "$SRC" ]; then
			"$SPLASH_BIN" -i "$SRC" "$@"
			return $?
		fi
	done

	return 1
}

GPTOKEYB() {
	PM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
	GPTOKEYB_DIR="$MUOS_SHARE_DIR/emulator/gptokeyb"

	if [ -f "$GPTOKEYB_DIR/$2.gptk" ]; then
		LIB_IPOSE="libinterpose.aarch64.so"
		ln -sf "$PM_DIR/$LIB_IPOSE" "/usr/lib/$LIB_IPOSE" >/dev/null 2>&1
		"$PM_DIR"/gptokeyb2 "$1" -c "$GPTOKEYB_DIR/$2.gptk" >/dev/null 2>&1 &
	fi
}

TERMINATE_SYNCTHING() {
	if [ "$(GET_VAR "config" "web/syncthing")" -eq 1 ]; then
		LOG_INFO "$0" 0 "HALT" "Shutdown Syncthing gracefully"
		SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$MUOS_STORE_DIR/syncthing/config.xml")
		CURL_OUTPUT=$(
			curl -s --connect-timeout 1 --max-time 2 -o /dev/null -w "%{http_code}" \
				-X POST -H "X-API-Key: $SYNCTHING_API" \
				"http://localhost:7070/rest/system/shutdown"
		)
		[ "$CURL_OUTPUT" -eq 200 ] && LOG_INFO "$0" 0 "HALT" "Syncthing shutdown request sent successfully"
	fi
}

# Terminate any active SSH connections, then bring down SSH itself
STOP_SSHD_GRACEFUL() {
	pkill -TERM -f 'sshd:.*@' >/dev/null 2>&1
	sleep 0.2
	pkill -TERM -f sshd >/dev/null 2>&1
}

LOG_CLEANER() {
	LOG_DIR="$(GET_VAR "device" "storage/rom/mount")"
	DAYS=7

	find "$LOG_DIR" -type f -name '*.log' -mtime +"$DAYS" -exec rm -f -- {} +
}

SAVE_CPU_GOV() {
	GOV_PATH="${1:-$(GET_VAR "device" "cpu/governor")}"
	GOV_WAKE="${2:-"$MUOS_RUN_DIR/wake_cpu_gov"}"

	read -r GOV <"$GOV_PATH" || return 1
	GOV=${GOV%%[[:space:]]*}

	[ -n "$GOV" ] || return 1

	printf "%s" "$GOV" >"$GOV_WAKE"
}

RESTORE_CPU_GOV() {
	GOV_PATH="${1:-$(GET_VAR "device" "cpu/governor")}"
	GOV_WAKE="${2:-"$MUOS_RUN_DIR/wake_cpu_gov"}"

	[ -f "$GOV_WAKE" ] || return 1

	read -r GOV <"$GOV_WAKE"
	GOV=${GOV%%[[:space:]]*}

	i=0
	while [ ! -w "$GOV_PATH" ] && [ $i -lt 30 ]; do
		sleep 0.05
		i=$((i + 1))
	done

	if [ -n "$GOV" ] && [ -w "$GOV_PATH" ]; then
		printf "%s" "$GOV" >"$GOV_PATH"
	fi
}

IS_MUTERM() {
	COMM=
	read -r COMM </proc/$PPID/comm 2>/dev/null
	[ "$COMM" = "muterm" ]
}

FBCON_DISABLE() {
	# TODO: Add advanced option for blinkies! (for antiKk)
	for VTCON in /sys/class/vtconsole/vtcon*; do
		[ -e "$VTCON/name" ] || continue

		VT_NAME=
		read -r VT_NAME <"$VTCON/name" 2>/dev/null
		case "$VT_NAME" in
			*frame*buffer* | *fbcon*) [ -w "$VTCON/bind" ] && printf "0\n" >"$VTCON/bind" ;;
		esac
	done

	[ -w /sys/class/graphics/fbcon/cursor_blink ] && printf "0\n" >/sys/class/graphics/fbcon/cursor_blink
	[ -w /sys/module/vt/parameters/default_utf8 ] && printf "1\n" >/sys/module/vt/parameters/default_utf8
}

ACT_GO="${ACT_GO:-/tmp/act_go}"
APP_GO="${APP_GO:-/tmp/app_go}"
GOV_GO="${GOV_GO:-/tmp/gov_go}"
CON_GO="${CON_GO:-/tmp/con_go}"
FLT_GO="${FLT_GO:-/tmp/flt_go}"
RAC_GO="${RAC_GO:-/tmp/rac_go}"
ROM_GO="${ROM_GO:-/tmp/rom_go}"
SAA_GO="${SAA_GO:-/tmp/saa_go}"
SAG_GO="${SAG_GO:-/tmp/sag_go}"
SAR_GO="${SAR_GO:-/tmp/sar_go}"
SHD_GO="${SHD_GO:-/tmp/shd_go}"
OVL_GO="${OVL_GO:-/tmp/ovl_go}"
EX_CARD="${EX_CARD:-/tmp/explore_card}"

SAFE_WRITE() {
	printf '%s\n' "$1" >"$2"
}

IS_ONE() {
	[ "$1" = "1" ]
}

READ_FIRST_LINE() {
	[ -r "$1" ] || return 1
	READ_LINE=
	IFS= read -r READ_LINE <"$1" || return 1
	printf '%s\n' "$READ_LINE"
}

ENSURE_REMOVED_SYNC() {
	REMOVE_PATH=$1
	REMOVE_COUNT=0

	while [ -e "$REMOVE_PATH" ] && [ "$REMOVE_COUNT" -lt 10 ]; do
		rm -f -- "$REMOVE_PATH" 2>/dev/null
		[ -e "$REMOVE_PATH" ] || break
		REMOVE_COUNT=$((REMOVE_COUNT + 1))
		sleep 0.1
	done
}

REMOVE_RUNTIME_FILES() {
	for RUNTIME_FILE in ra_no_load ra_autoload_once.cfg; do
		ENSURE_REMOVED_SYNC "/tmp/$RUNTIME_FILE"
	done

	ENSURE_REMOVED_SYNC "$CON_GO"
	ENSURE_REMOVED_SYNC "$FLT_GO"
	ENSURE_REMOVED_SYNC "$OVL_GO"
	ENSURE_REMOVED_SYNC "$RAC_GO"
	ENSURE_REMOVED_SYNC "$SHD_GO"
	ENSURE_REMOVED_SYNC "$MUOS_RUN_DIR/overlay.filter"
	ENSURE_REMOVED_SYNC "$MUOS_RUN_DIR/overlay.shader"
}

RESET_LAUNCHER_FLAGS() {
	ENSURE_REMOVED_SYNC "$GOV_GO"
	ENSURE_REMOVED_SYNC "$CON_GO"
	ENSURE_REMOVED_SYNC "$FLT_GO"
	ENSURE_REMOVED_SYNC "$SHD_GO"
	ENSURE_REMOVED_SYNC "$RAC_GO"
	ENSURE_REMOVED_SYNC "$SAA_GO"
	ENSURE_REMOVED_SYNC "$SAG_GO"
	ENSURE_REMOVED_SYNC "$SAR_GO"
}

RESET_APP_FLAGS() {
	ENSURE_REMOVED_SYNC "$GOV_GO"
	ENSURE_REMOVED_SYNC "$CON_GO"
}

WAIT_FOR_AUDIO_READY() {
	AUDIO_WAIT_MAX=${1:-100}
	AUDIO_WAIT=0

	LOG_INFO "$0" 0 "BOOTING" "Waiting for PipeWire initialisation"

	while [ "$AUDIO_WAIT" -lt "$AUDIO_WAIT_MAX" ]; do
		[ "$(GET_VAR "device" "audio/ready")" = "1" ] && return 0
		AUDIO_WAIT=$((AUDIO_WAIT + 1))
		sleep 0.1
	done

	LOG_WARN "$0" 0 "BOOTING" "PipeWire initialisation wait timed out"
	return 1
}

RESET_DPAD_MODE() {
	BOARD_STICK_VALUE=${1:-$(GET_VAR "device" "board/stick")}
	BOARD_NAME_VALUE=${2:-$(GET_VAR "device" "board/name")}
	DPAD_SWAP_PATH=${3:-$(GET_VAR "device" "board/swap")}

	IS_ONE "$BOARD_STICK_VALUE" && return 0

	case "$BOARD_NAME_VALUE" in
		rg*) printf "0" >"$DPAD_SWAP_PATH" ;;
		tui*) ENSURE_REMOVED_SYNC "$DPAD_SWAP_PATH" ;;
	esac
}

COPY_IF_AVAILABLE() {
	SETTING_NAME=$1
	CONTENT_FILE=$2
	FALLBACK_FILE=$3
	OUTPUT_FILE=$4

	if [ -e "$CONTENT_FILE" ]; then
		cat "$CONTENT_FILE" >"$OUTPUT_FILE"
	elif [ -e "$FALLBACK_FILE" ]; then
		cat "$FALLBACK_FILE" >"$OUTPUT_FILE"
	else
		LOG_INFO "$0" 0 "FRONTEND" "No $SETTING_NAME file found for launched content"
	fi
}

COPY_CONTENT_SETTINGS() {
	CONTENT_BASE=$1
	CONTENT_DIR=$2

	COPY_IF_AVAILABLE "governor" "$CONTENT_DIR/$CONTENT_BASE.gov" "$CONTENT_DIR/core.gov" "$GOV_GO"
	COPY_IF_AVAILABLE "control" "$CONTENT_DIR/$CONTENT_BASE.con" "$CONTENT_DIR/core.con" "$CON_GO"
	COPY_IF_AVAILABLE "retroarch" "$CONTENT_DIR/$CONTENT_BASE.rac" "$CONTENT_DIR/core.rac" "$RAC_GO"
	COPY_IF_AVAILABLE "filter" "$CONTENT_DIR/$CONTENT_BASE.flt" "$CONTENT_DIR/core.flt" "$FLT_GO"
	COPY_IF_AVAILABLE "shader" "$CONTENT_DIR/$CONTENT_BASE.shd" "$CONTENT_DIR/core.shd" "$SHD_GO"
}

APPLY_OPTIONAL_FILE() {
	SOURCE_FILE=$1
	TARGET_FILE=$2
	DESCRIPTION=$3

	if [ -s "$SOURCE_FILE" ]; then
		LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Applying %s from '%s' to '%s'" "$DESCRIPTION" "$SOURCE_FILE" "$TARGET_FILE")"
		cat "$SOURCE_FILE" >"$TARGET_FILE"
		return $?
	fi

	LOG_WARN "$0" 0 "LAUNCH" "$(printf "Missing %s file: '%s'" "$DESCRIPTION" "$SOURCE_FILE")"
	return 1
}

RESTORE_DPAD_AND_LEDS() {
	RESTORE_BOARD_NAME=${1:-$(GET_VAR "device" "board/name")}
	RESTORE_DPAD_SWAP=${2:-$(GET_VAR "device" "board/swap")}
	RESTORE_LED_NORMAL=${3:-$(GET_VAR "device" "led/normal")}
	RESTORE_LED_STATE=${4:-"$MUOS_RUN_DIR/work_led_state"}

	[ "$(GET_VAR "device" "board/stick")" = "1" ] && return 0

	case "$RESTORE_BOARD_NAME" in
		rg*)
			LOG_DEBUG "$0" 0 "LAUNCH" "Resetting DPAD swap and LED state for rg* board"
			printf "0" >"$RESTORE_DPAD_SWAP"
			printf "1" >"$RESTORE_LED_NORMAL"
			printf "1" >"$RESTORE_LED_STATE"
			;;
		tui*)
			ENSURE_REMOVED_SYNC "$RESTORE_DPAD_SWAP"
			;;
		*) ;;
	esac
}

RESTORE_FRAMEBUFFER_MODE() {
	DEVICE_MODE_VALUE=${1:-$(GET_VAR "config" "boot/device_mode")}
	INTERNAL_WIDTH=${2:-$(GET_VAR "device" "screen/internal/width")}
	INTERNAL_HEIGHT=${3:-$(GET_VAR "device" "screen/internal/height")}
	EXTERNAL_WIDTH=${4:-$(GET_VAR "device" "screen/external/width")}
	EXTERNAL_HEIGHT=${5:-$(GET_VAR "device" "screen/external/height")}

	if IS_ONE "$DEVICE_MODE_VALUE"; then
		LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Switching framebuffer to external %sx%s@32" "$EXTERNAL_WIDTH" "$EXTERNAL_HEIGHT")"
		FB_SWITCH "$EXTERNAL_WIDTH" "$EXTERNAL_HEIGHT" 32
	else
		LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Switching framebuffer to internal %sx%s@32" "$INTERNAL_WIDTH" "$INTERNAL_HEIGHT")"
		FB_SWITCH "$INTERNAL_WIDTH" "$INTERNAL_HEIGHT" 32
	fi
}

RUN_SYNCTHING_SCAN() {
	USE_SYNCTHING_VALUE=${1:-$(GET_VAR "config" "web/syncthing")}
	AUTO_SCAN_VALUE=${2:-$(GET_VAR "config" "syncthing/auto_scan")}
	NET_STATE_PATH=${3:-$(GET_VAR "device" "network/state")}

	IS_ONE "$USE_SYNCTHING_VALUE" || return 0
	IS_ONE "$AUTO_SCAN_VALUE" || return 0
	[ -r "$NET_STATE_PATH" ] || return 0
	[ "$(READ_FIRST_LINE "$NET_STATE_PATH")" = "up" ] || return 0

	SYNCTHING_CONFIG="$MUOS_STORE_DIR/syncthing/config.xml"
	[ -r "$SYNCTHING_CONFIG" ] || {
		LOG_WARN "$0" 0 "LAUNCH" "Syncthing config not readable; skipping folder rescan"
		return 0
	}

	SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$SYNCTHING_CONFIG")
	[ -n "$SYNCTHING_API" ] || {
		LOG_WARN "$0" 0 "LAUNCH" "Syncthing API key missing; skipping folder rescan"
		return 0
	}

	LOG_INFO "$0" 0 "LAUNCH" "Triggering Syncthing folder rescan"

	if command -v curl >/dev/null 2>&1; then
		curl --silent --show-error --max-time 5 \
			-X POST \
			-H "X-API-Key: $SYNCTHING_API" \
			"http://localhost:7070/rest/db/scan" >/dev/null 2>&1 ||
			LOG_WARN "$0" 0 "LAUNCH" "Syncthing folder rescan failed"
	fi
}
