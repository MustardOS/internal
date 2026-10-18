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
MUOS_LOG_BIN="/opt/muos/frontend/mulog"
MUOS_RGB_BIN="/opt/muos/frontend/murgb"
MUOS_VAR_BIN="/opt/muos/frontend/muvarctl"
MUOS_RUN_DIR="/run/muos"
MUOS_SHARE_DIR="/opt/muos/share"
MUOS_STORE_DIR="$MUOS_RUN_DIR/storage"
OVERLAY_NOP="$MUOS_RUN_DIR/overlay.disable"
IS_IDLE="$MUOS_RUN_DIR/is_idle"

jq() {
	if [ -x /opt/muos/bin/jq ]; then
		/opt/muos/bin/jq "$@"
	else
		/usr/bin/jq "$@"
	fi
}
IDLE_STATE="$MUOS_RUN_DIR/idle_state"

export HOME XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS PIPEWIRE_RUNTIME_DIR \
	ALSA_CONFIG WPA_CONFIG DEVICE_CONTROL_DIR MUOS_LOG_DIR MUOS_LOG_BIN \
	MUOS_RGB_BIN MUOS_VAR_BIN MUOS_RUN_DIR MUOS_SHARE_DIR MUOS_STORE_DIR OVERLAY_NOP \
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

TBOX() {
	CMD=$1
	shift

	/opt/muos/bin/toybox "$CMD" "$@"
}

IS_ONE() {
	[ "$1" = "1" ]
}
