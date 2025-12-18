#!/bin/sh

. /opt/muos/script/var/func.sh

PF_INTERNAL="$(GET_VAR "device" "audio/pf_internal")"
PF_EXTERNAL="$(GET_VAR "device" "audio/pf_external")"
MAX_VOL="$(GET_VAR "device" "audio/max")"
READY="$(GET_VAR "device" "audio/ready")"

BOOT_CONSOLE_MODE="$(GET_VAR "config" "boot/device_mode")"
HDMI_INTERNAL_AUDIO=$(GET_VAR "config" "settings/hdmi/audio")
GEN_VOL="$(GET_VAR "config" "settings/general/volume")"
ADV_VOL="$(GET_VAR "config" "settings/advanced/volume")"
ADV_OD="$(GET_VAR "config" "settings/advanced/overdrive")"
ADV_AR="$(GET_VAR "config" "settings/advanced/audio_ready")"

DBUS_SOCKET="/run/dbus/system_bus_socket"
PW_SOCKET="/run/pipewire-0"

TIMEOUT=3000
INTERVAL=100

SOCKET_READY() {
	[ -S "$PW_SOCKET" ] || return 1
	pw-cli info || return 1
	return 0
}

PROC_GONE() {
	NAME=$1

	ELAPSED=0
	while pgrep -x "$NAME"; do
		sleep 0.1
		ELAPSED=$((ELAPSED + INTERVAL))
		[ "$ELAPSED" -ge "$TIMEOUT" ] && return 1
	done

	return 0
}

RESTORE_CONF() {
	SRC=$1
	DST=$2

	[ -f "$DST" ] && cmp -s "$SRC" "$DST" && return 0
	cp -f "$SRC" "$DST"
}

GET_NODE_ID() {
	pw-dump | jq -r '.[] | select(.type=="PipeWire:Interface:Node") | "\(.id) \(.info.props["node.name"])" ' |
		grep -F "$1" | awk '{print $1}'
}

GET_TARGET_NODE() {
	TARGET_ID=

	if [ "$BOOT_CONSOLE_MODE" -eq 1 ]; then
		TARGET_ID="$PF_EXTERNAL"
		[ "$HDMI_INTERNAL_AUDIO" -eq 1 ] && TARGET_ID="$PF_INTERNAL"
	else
		TARGET_ID="$PF_INTERNAL"
	fi

	ELAPSED=0
	until pw-dump | grep -q "$TARGET_ID" || [ "$ELAPSED" -ge "$TIMEOUT" ]; do
		sleep 0.1
		ELAPSED=$((ELAPSED + INTERVAL))
	done

	printf '%s' "$TARGET_ID"
}

FINALISE_AUDIO() {
	TARGET_ID=$(GET_TARGET_NODE)
	DEF_ID=""

	ELAPSED=0
	while [ -z "$DEF_ID" ]; do
		sleep 0.1
		ELAPSED=$((ELAPSED + INTERVAL))

		DEF_ID="$(GET_NODE_ID "$TARGET_ID")"
		[ -n "$DEF_ID" ] && break

		[ "$ELAPSED" -ge "$TIMEOUT" ] && break
	done

	if [ -z "$DEF_ID" ]; then
		LOG_WARN "$0" 0 "PIPEWIRE" "$(printf "No matching PipeWire node for target '%s' after timeout" "$TARGET_ID")"
		[ "$ADV_AR" -eq 1 ] && SET_VAR "device" "audio/ready" "1"
		return 1
	fi

	wpctl set-default "$DEF_ID"

	case "$ADV_VOL" in
		loud) V="$MAX_VOL" ;;
		soft) V=35 ;;
		silent) V=0 ;;
		*) V="$GEN_VOL" ;;
	esac

	if [ "$BOOT_CONSOLE_MODE" -eq 1 ]; then
		if [ "${ADV_OD:-0}" -eq 1 ]; then V=200; else V=100; fi
	fi

	wpctl set-volume @DEFAULT_AUDIO_SINK@ "$V"%
	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0

	RESET_AMIXER

	[ "$ADV_AR" -eq 1 ] && SET_VAR "device" "audio/ready" "1"

	LOG_SUCCESS "$0" 0 "PIPEWIRE" "$(printf "Audio Finalised (node=%s, vol=%s%%)" "$DEF_ID" "$V")"
	return 0
}

START_PIPEWIRE() {
	RESTORE_CONF "$MUOS_SHARE_DIR/conf/wireplumber.lua" "/usr/share/wireplumber/main.lua.d/60-muos-wireplumber.lua"

	if ! pgrep -x "pipewire"; then
		LOG_INFO "$0" 0 "PIPEWIRE" "$(printf "Starting PipeWire (runtime: %s)" "$PIPEWIRE_RUNTIME_DIR")"
		chrt -f 88 pipewire -c "$MUOS_SHARE_DIR/conf/pipewire.conf" &
	else
		LOG_WARN "$0" 0 "PIPEWIRE" "PipeWire already running"
	fi

	if ! pgrep -x "wireplumber"; then
		LOG_INFO "$0" 0 "PIPEWIRE" "Starting WirePlumber..."
		wireplumber &
	fi

	return 0
}

DO_START() {
	if ! START_PIPEWIRE; then
		LOG_ERROR "$0" 0 "PIPEWIRE" "Failed to start"
		[ "$ADV_AR" -eq 1 ] && SET_VAR "device" "audio/ready" "1"
		exit 1
	fi

	LOG_INFO "$0" 0 "PIPEWIRE" "Restoring Default Sound System"
	RESTORE_CONF "$MUOS_SHARE_DIR/conf/asound.conf" "/etc/asound.conf"

	LOG_INFO "$0" 0 "PIPEWIRE" "ALSA Config Restoring"
	RESTORE_CONF "$MUOS_SHARE_DIR/conf/alsa.conf" "/usr/share/alsa/alsa.conf"

	LOG_INFO "$0" 0 "PIPEWIRE" "Restoring Audio State"
	alsactl -U -f "$DEVICE_CONTROL_DIR/asound.state" restore

	ELAPSED=0
	while [ ! -S "$DBUS_SOCKET" ]; do
		sleep 0.1
		ELAPSED=$((ELAPSED + INTERVAL))
		[ "$ELAPSED" -ge "$TIMEOUT" ] && break
	done

	if [ -S "$DBUS_SOCKET" ]; then
		LOG_SUCCESS "$0" 0 "PIPEWIRE" "D-Bus socket is available"
	else
		LOG_WARN "$0" 0 "PIPEWIRE" "D-Bus not ready after 3s; proceeding"
	fi

	FINALISE_AUDIO

	exit 0
}

DO_STOP() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Audio shutdown sequence..."

	wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.01

	for PROC in pipewire wireplumber; do
		pkill -15 "$PROC" 2>/dev/null
		PROC_GONE "$PROC" "$PROC_GONE_TIMEOUT_MS" || pkill -9 "$PROC" 2>/dev/null
	done

	[ "$ADV_AR" -eq 1 ] && SET_VAR "device" "audio/ready" "0"
	LOG_SUCCESS "$0" 0 "PIPEWIRE" "Audio shutdown complete"
}

DO_RELOAD() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Reloading audio routing/volume"

	if SOCKET_READY; then
		if FINALISE_AUDIO; then
			LOG_SUCCESS "$0" 0 "PIPEWIRE" "Reload complete"
			exit 0
		fi
	fi

	LOG_WARN "$0" 0 "PIPEWIRE" "Reload incomplete (daemon/socket not ready)"
	exit 1
}

PRINT_STATUS() {
	SOCK=0
	SINK=0

	SOCKET_READY && SOCK=1
	pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink" && SINK=1

	DEF_SINK=$(wpctl status 2>/dev/null | awk -F': ' '/Default Sink:/ {print $2; exit}')

	PW_PID="$(pgrep -xo pipewire)"
	WP_PID="$(pgrep -xo wireplumber)"

	printf "PipeWire:\t\t%s\n" "$([ -n "$PW_PID" ] && printf "running\t\t%s" "$PW_PID" || printf "stopped")"
	printf "WirePlumber:\t\t%s\n" "$([ -n "$WP_PID" ] && printf "running\t\t%s" "$WP_PID" || printf "stopped")"
	printf "Socket:\t\t\t%s\n" "$([ "$SOCK" -eq 1 ] && printf "ready\t\t%s" "$PW_SOCKET" || printf "not ready")"
	printf "Audio Sink:\t\t%s%s\n" "$([ "$SINK" -eq 1 ] && printf "available" || printf "missing")" "$([ -n "$DEF_SINK" ] && printf " (default: %s)" "$DEF_SINK" || printf "")"
	printf "MustardOS Ready:\t%s\n" "$([ "$READY" = "1" ] && printf "yes" || printf "no")"

	[ "$RUNNING" -ne 1 ] && return 3
	[ "$SOCK" -eq 1 ] && [ "$SINK" -eq 1 ] && return 0

	return 1
}

case "$1" in
	start) DO_START ;;
	stop) DO_STOP ;;
	restart)
		DO_STOP
		DO_START
		;;
	reload) DO_RELOAD ;;
	status)
		if PRINT_STATUS; then
			exit 0
		else
			EC=$?
			exit "$EC"
		fi
		;;
	*)
		printf "Usage: %s {start|stop|restart|reload|status}\n" "$0"
		exit 1
		;;
esac
