#!/bin/sh

. /opt/muos/script/var/func.sh

PF_INTERNAL=$(GET_VAR "device" "audio/pf_internal")
PF_EXTERNAL=$(GET_VAR "device" "audio/pf_external")

BOOT_CONSOLE_MODE=$(GET_VAR "config" "boot/device_mode")
HDMI_INTERNAL_AUDIO=$(GET_VAR "config" "settings/hdmi/audio")

ADV_VOL=$(GET_VAR "config" "settings/advanced/volume")
ADV_OD=$(GET_VAR "config" "settings/advanced/overdrive")
ADV_AR=$(GET_VAR "config" "settings/advanced/audio_ready")

DBUS_SOCKET="/run/dbus/system_bus_socket"

XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run}
PIPEWIRE_RUNTIME_DIR=${PIPEWIRE_RUNTIME_DIR:-$XDG_RUNTIME_DIR}
PW_SOCKET="${PIPEWIRE_RUNTIME_DIR}/pipewire-0"

TIMEOUT=3000
INTERVAL=100

SOCKET_READY() {
	[ -S "$PW_SOCKET" ] || return 1
	pw-cli info 0 >/dev/null 2>&1
}

PROC_RUNNING() {
	pgrep -x "$1" >/dev/null 2>&1
}

WAIT_UNTIL() {
	COND_FN="$1"
	ARG="$2"
	ELAPSED=0

	while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
		"$COND_FN" "$ARG" && return 0
		sleep 0.1
		ELAPSED=$((ELAPSED + INTERVAL))
	done

	return 1
}

WAIT_PROC_GONE() {
	NAME=$1
	WAIT_UNTIL PROC_RUNNING "$NAME" && return 1

	return 0
}

RESTORE_CONF() {
	SRC=$1
	DST=$2

	[ -f "$SRC" ] || return 1
	[ -f "$DST" ] && cmp -s "$SRC" "$DST" && return 0

	cp -f "$SRC" "$DST"
}

GET_TARGET_NODE() {
	TARGET_ID=$PF_INTERNAL

	if [ "${BOOT_CONSOLE_MODE:-0}" -eq 1 ]; then
		TARGET_ID=$PF_EXTERNAL
		[ "${HDMI_INTERNAL_AUDIO:-0}" -eq 1 ] && TARGET_ID=$PF_INTERNAL
	fi

	printf "%s\n" "$TARGET_ID"
}

GET_NODE_ID() {
	TARGET_NAME=$1

	pw-dump 2>/dev/null |
		jq -r '
			.[] |
			select(.type == "PipeWire:Interface:Node") |
			select(.info.props["node.name"] != null) |
			"\(.id)\t\(.info.props["node.name"])"
		' 2>/dev/null |
		awk -F '\t' -v target="$TARGET_NAME" '$2 == target { print $1; exit }'
}

NODE_VISIBLE() {
	[ -n "$(GET_NODE_ID "$1")" ]
}

DBUS_READY() {
	[ -S "$DBUS_SOCKET" ]
}

ADV_VOL_TO_PERCENT() {
	case "$1" in
		1) printf "0\n" ;;
		2) printf "35\n" ;;
		3) printf "%s\n" "$(GET_VAR "device" "audio/max")" ;;
	esac
}

GET_BOOT_RUNTIME_PERCENT() {
	if [ "${BOOT_CONSOLE_MODE:-0}" -eq 1 ]; then
		[ "${ADV_OD:-0}" -eq 1 ] && printf "200\n" || printf "100\n"
	else
		ADV_VOL_TO_PERCENT "$ADV_VOL"
	fi
}

GET_BOOT_SAVED_VOLUME() {
	case "$ADV_VOL" in
		1 | 2 | 3) ADV_VOL_TO_PERCENT "$ADV_VOL" ;;
		*) GET_SAVED_AUDIO_VOLUME ;;
	esac
}

INSTALL_WIREPLUMBER_CONF() {
	# Determine the WirePlumber minor version to select the correct config format.
	WP_MINOR=$(wireplumber --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d. -f2)

	if [ "${WP_MINOR:-0}" -ge 5 ]; then
		# WirePlumber 5+
		RESTORE_CONF "$DEVICE_CONTROL_DIR/wireplumber.conf" \
			"/usr/share/wireplumber/wireplumber.conf.d/60-muos-wireplumber.conf"
	else
		# WirePlumber 4
		RESTORE_CONF "$DEVICE_CONTROL_DIR/wireplumber.lua" \
			"/usr/share/wireplumber/main.lua.d/60-muos-wireplumber.lua"
	fi
}

STOP_PROC() {
	NAME=$1

	if PROC_RUNNING "$NAME"; then
		pkill -15 -x "$NAME" 2>/dev/null
		WAIT_PROC_GONE "$NAME" || pkill -9 -x "$NAME" 2>/dev/null
	fi
}

START_PIPEWIRE() {
	INSTALL_WIREPLUMBER_CONF

	if SOCKET_READY; then
		LOG_WARN "$0" 0 "PIPEWIRE" "PipeWire already running and socket is ready"
	else
		if PROC_RUNNING pipewire; then
			LOG_WARN "$0" 0 "PIPEWIRE" "PipeWire process exists but socket is not ready; restarting"
			STOP_PROC pipewire
		fi

		LOG_INFO "$0" 0 "PIPEWIRE" "$(printf "Starting PipeWire (runtime: %s)" "$PIPEWIRE_RUNTIME_DIR")"
		PIPEWIRE_RUNTIME_DIR="$PIPEWIRE_RUNTIME_DIR" \
			XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
			chrt -f 88 pipewire -c "$MUOS_SHARE_DIR/conf/pipewire.conf" >/dev/null 2>&1 &
	fi

	if PROC_RUNNING wireplumber; then
		LOG_WARN "$0" 0 "PIPEWIRE" "WirePlumber already running"
	else
		LOG_INFO "$0" 0 "PIPEWIRE" "Starting WirePlumber..."
		PIPEWIRE_RUNTIME_DIR="$PIPEWIRE_RUNTIME_DIR" \
			XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
			DBUS_SESSION_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket" \
			wireplumber >/dev/null 2>&1 &
	fi

	return 0
}

FINALISE_AUDIO() {
	USE_SAVED=${1:-0}
	TARGET_NAME=$(GET_TARGET_NODE)
	RUNTIME_PERCENT=$(GET_BOOT_RUNTIME_PERCENT)
	SAVED_VOL=$(GET_BOOT_SAVED_VOLUME)

	SET_SAVED_AUDIO_VOLUME "$SAVED_VOL"

	if [ "$USE_SAVED" -eq 1 ]; then
		APPLY_VOL=$SAVED_VOL
	else
		APPLY_VOL=${RUNTIME_PERCENT:-$SAVED_VOL}
	fi

	# Wait for the target node to appear, then resolve its ID once and cache it.
	if ! WAIT_UNTIL NODE_VISIBLE "$TARGET_NAME"; then
		LOG_WARN "$0" 0 "PIPEWIRE" "$(printf "Target node '%s' not ready after timeout" "$TARGET_NAME")"
		[ "${ADV_AR:-0}" -eq 1 ] && SET_VAR "device" "audio/ready" "1"
		return 1
	fi

	DEF_ID=$(GET_NODE_ID "$TARGET_NAME")
	if [ -z "$DEF_ID" ]; then
		LOG_WARN "$0" 0 "PIPEWIRE" "$(printf "Unable to resolve node ID for target '%s'" "$TARGET_NAME")"
		[ "${ADV_AR:-0}" -eq 1 ] && SET_VAR "device" "audio/ready" "1"
		return 1
	fi

	wpctl set-default "$DEF_ID" >/dev/null 2>&1 ||
		LOG_WARN "$0" 0 "PIPEWIRE" "$(printf "Unable to set default node '%s'" "$DEF_ID")"

	APPLY_VOL=${RUNTIME_PERCENT:-$SAVED_VOL}
	if [ "${WP_MINOR:-0}" -ge 5 ]; then
		# WirePlumber 5+
		WPCTL_VOL=$(awk "BEGIN { printf \"%.2f\", ${APPLY_VOL}/100 }")
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$WPCTL_VOL" >/dev/null 2>&1
	else
		# WirePlumber 4
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "${APPLY_VOL}%" >/dev/null 2>&1
	fi

	sleep 0.1
	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1

	[ "${ADV_AR:-0}" -eq 1 ] && SET_VAR "device" "audio/ready" "1"

	LOG_SUCCESS "$0" 0 "PIPEWIRE" "$(printf "Audio finalised (node=%s, volume=%s%%)" "$DEF_ID" "$APPLY_VOL")"
	return 0
}

DO_START() {
	[ "${ADV_AR:-0}" -eq 1 ] && SET_VAR "device" "audio/ready" "0"

	LOG_INFO "$0" 0 "PIPEWIRE" "Restoring Default Sound System"
	RESTORE_CONF "$MUOS_SHARE_DIR/conf/asound.conf" "/etc/asound.conf"

	LOG_INFO "$0" 0 "PIPEWIRE" "Restoring ALSA Config"
	RESTORE_CONF "$MUOS_SHARE_DIR/conf/alsa.conf" "/usr/share/alsa/alsa.conf"

	if ! START_PIPEWIRE; then
		LOG_ERROR "$0" 0 "PIPEWIRE" "Failed to start"
		[ "${ADV_AR:-0}" -eq 1 ] && SET_VAR "device" "audio/ready" "1"
		exit 1
	fi

	WAIT_UNTIL DBUS_READY || LOG_WARN "$0" 0 "PIPEWIRE" "D-Bus not ready after timeout; proceeding"

	if ! WAIT_UNTIL SOCKET_READY; then
		LOG_WARN "$0" 0 "PIPEWIRE" "$(printf "PipeWire socket '%s' not ready after timeout" "$PW_SOCKET")"
		[ "${ADV_AR:-0}" -eq 1 ] && SET_VAR "device" "audio/ready" "1"
		exit 1
	fi

	LOG_SUCCESS "$0" 0 "PIPEWIRE" "$(printf "PipeWire socket is available (%s)" "$PW_SOCKET")"
	wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 >/dev/null 2>&1

	LOG_INFO "$0" 0 "PIPEWIRE" "Restoring Audio State"
	alsactl -U -f "$DEVICE_CONTROL_DIR/asound.state" restore >/dev/null 2>&1

	RESET_MIXER

	FINALISE_AUDIO || exit 1
	exit 0
}

DO_STOP() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Audio shutdown sequence..."

	if SOCKET_READY; then
		wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 >/dev/null 2>&1
		sleep 0.1
		alsactl -U -f "$DEVICE_CONTROL_DIR/asound.state" store >/dev/null 2>&1
	fi

	STOP_PROC wireplumber
	STOP_PROC pipewire

	[ "${ADV_AR:-0}" -eq 1 ] && SET_VAR "device" "audio/ready" "0"
	LOG_SUCCESS "$0" 0 "PIPEWIRE" "Audio shutdown complete"
}

DO_RELOAD() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Reloading audio routing/volume"

	if ! SOCKET_READY; then
		LOG_WARN "$0" 0 "PIPEWIRE" "Reload incomplete (daemon/socket not ready)"
		exit 1
	fi

	if FINALISE_AUDIO 1; then
		LOG_SUCCESS "$0" 0 "PIPEWIRE" "Reload complete"
		exit 0
	fi

	LOG_WARN "$0" 0 "PIPEWIRE" "Reload incomplete"
	exit 1
}

PRINT_STATUS() {
	READY=$(GET_VAR "device" "audio/ready")
	SOCK=0
	SINK=0
	PW_RUNNING=0
	WP_RUNNING=0
	DEF_SINK=
	PW_PID=
	WP_PID=

	PROC_RUNNING pipewire && PW_RUNNING=1
	PROC_RUNNING wireplumber && WP_RUNNING=1
	SOCKET_READY && SOCK=1

	if [ "$SOCK" -eq 1 ]; then
		pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink" && SINK=1
		DEF_SINK=$(wpctl status 2>/dev/null | awk -F': ' '/Default Sink:/ { print $2; exit }')
	fi

	PW_PID=$(pgrep -o -x pipewire 2>/dev/null)
	WP_PID=$(pgrep -o -x wireplumber 2>/dev/null)

	printf "PipeWire:\t\t%s\n" "$([ "$PW_RUNNING" -eq 1 ] && printf "running\t\t%s" "${PW_PID:-unknown}" || printf "stopped")"
	printf "WirePlumber:\t\t%s\n" "$([ "$WP_RUNNING" -eq 1 ] && printf "running\t\t%s" "${WP_PID:-unknown}" || printf "stopped")"
	printf "Socket:\t\t\t%s\n" "$([ "$SOCK" -eq 1 ] && printf "ready\t\t%s" "$PW_SOCKET" || printf "not ready")"
	printf "Audio Sink:\t\t%s%s\n" "$([ "$SINK" -eq 1 ] && printf "available" || printf "missing")" "$([ -n "$DEF_SINK" ] && printf " (default: %s)" "$DEF_SINK" || printf "")"
	printf "MustardOS Ready:\t%s\n" "$([ "$READY" = "1" ] && printf "yes" || printf "no")"

	[ "$PW_RUNNING" -eq 1 ] && [ "$SOCK" -eq 1 ] && [ "$SINK" -eq 1 ] && return 0
	[ "$PW_RUNNING" -eq 0 ] && [ "$WP_RUNNING" -eq 0 ] && return 3

	return 1
}

case "${1:-}" in
	start) DO_START ;;
	stop) DO_STOP ;;
	restart)
		DO_STOP
		DO_START
		;;
	reload) DO_RELOAD ;;
	status)
		PRINT_STATUS
		exit "$?"
		;;
	*)
		printf "Usage: %s {start|stop|restart|reload|status}\n" "$0"
		exit 1
		;;
esac
