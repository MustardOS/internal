#!/bin/sh

[ -n "${MUOS_BASE_LOADED-}" ] && return 0
MUOS_BASE_LOADED=1

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
MUOS_LOG_BIN="/opt/muos/frontend/tool/mulog"
MUOS_RGB_BIN="/opt/muos/frontend/tool/murgb"
MUOS_TRACK_BIN="/opt/muos/frontend/tool/mutrack"
MUOS_VAR_BIN="/opt/muos/frontend/tool/muvarctl"
MUOS_RUN_DIR="/run/muos"
MUOS_SHARE_DIR="/opt/muos/share"
MUOS_STORE_DIR="$MUOS_RUN_DIR/storage"
OVERLAY_NOP="$MUOS_RUN_DIR/overlay.disable"
IS_IDLE="$MUOS_RUN_DIR/is_idle"

IDLE_STATE="$MUOS_RUN_DIR/idle_state"

export HOME XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS PIPEWIRE_RUNTIME_DIR \
	ALSA_CONFIG WPA_CONFIG DEVICE_CONTROL_DIR MUOS_LOG_DIR MUOS_LOG_BIN \
	MUOS_RGB_BIN MUOS_TRACK_BIN MUOS_VAR_BIN MUOS_RUN_DIR MUOS_SHARE_DIR MUOS_STORE_DIR OVERLAY_NOP \
	IS_IDLE IDLE_STATE

MUOS_CONF_GLOBAL="/opt/muos/config"
MUOS_CONF_DEVICE="/opt/muos/device/config"
MUOS_CONF_KIOSK="/opt/muos/kiosk"
MUOS_CONF_SYSTEM="/opt/muos/config/system"

export MUOS_CONF_GLOBAL MUOS_CONF_DEVICE MUOS_CONF_KIOSK MUOS_CONF_SYSTEM

[ -d "$MUOS_LOG_DIR" ] || mkdir -p "$MUOS_LOG_DIR"

DEVICE_SCRIPT_DIR="/opt/muos/script/device"

# Prints the path of a device script, preferring the board's own folder over the global one
DEVICE_SCRIPT() {
	DEVICE_SCRIPT_PATH="$DEVICE_SCRIPT_DIR/$(GET_VAR "device" "board/name")/$1"
	[ -f "$DEVICE_SCRIPT_PATH" ] || DEVICE_SCRIPT_PATH="$DEVICE_SCRIPT_DIR/$1"
	[ -f "$DEVICE_SCRIPT_PATH" ] || return 1
	printf '%s\n' "$DEVICE_SCRIPT_PATH"
}

# Runs a device script if this board has one, otherwise does nothing
RUN_DEVICE_SCRIPT() {
	RUN_DEVICE_SCRIPT_PATH=$(DEVICE_SCRIPT "$1") || return 0
	shift
	"$RUN_DEVICE_SCRIPT_PATH" "$@"
}

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


LOCK_RUN() {
	case " ${MUOS_LOCKS-} " in *" $1 "*) return 0 ;; esac
	LOCK_NAME=$1
	shift
	MUOS_LOCKS="${MUOS_LOCKS:+$MUOS_LOCKS }$LOCK_NAME" /usr/bin/flock -E 75 -w 60 "$MUOS_RUN_DIR/$LOCK_NAME.lock" "$0" "$@"
	LOCK_STATUS=$?
	return 1
}

IS_ONE() {
	[ "$1" = "1" ]
}

NET_STATE_FILE() {
	printf '/sys/class/net/%s/operstate' "$(GET_VAR "device" "network/iface")"
}

RTC_CLOCK() {
	for RTC_DIR in /sys/class/rtc/rtc*; do
		IFS= read -r RTC_VALUE <"$RTC_DIR/hctosys" 2>/dev/null || continue
		[ "$RTC_VALUE" = 1 ] && {
			printf '/dev/%s' "${RTC_DIR##*/}"
			return 0
		}
	done

	[ -e /dev/rtc0 ] && printf '/dev/rtc0'
}

RTC_WAKE() {
	for RTC_DIR in /sys/class/rtc/rtc*; do
		[ -e "$RTC_DIR/wakealarm" ] || continue
		IFS= read -r RTC_VALUE <"$RTC_DIR/device/power/wakeup" 2>/dev/null || continue
		[ "$RTC_VALUE" = enabled ] && {
			printf '%s' "$RTC_DIR"
			return 0
		}
	done

	RTC_DIR=$(RTC_CLOCK)
	RTC_DIR="/sys/class/rtc/${RTC_DIR##*/}"
	[ -e "$RTC_DIR/wakealarm" ] && printf '%s' "$RTC_DIR"
}
