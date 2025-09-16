#!/bin/sh

. /opt/muos/script/var/func.sh

ACTION=$1

FAST_READY_TIMEOUT_MS=5000
FAST_READY_POLL_MS=100
SINK_DISCOVERY_TIMEOUT_MS=3000
SINK_DISCOVERY_POLL_MS=100
PROC_GONE_TIMEOUT_MS=3000

RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/run/pipewire-0}}"
RUNTIME_SOCK="$RUNTIME_DIR/pipewire-0"

RUNTIME_DIR_INIT() {
	mkdir -p "$RUNTIME_DIR" || true
	chmod 700 "$RUNTIME_DIR" || true
	export XDG_RUNTIME_DIR="$RUNTIME_DIR"
}

SOCKET_READY() {
	[ -S "$RUNTIME_SOCK" ] || return 1
	XDG_RUNTIME_DIR="$RUNTIME_DIR" pw-cli info >/dev/null 2>&1 || return 1
	return 0
}

SLEEP_MS() {
	SEC=$(awk "BEGIN{printf \"%.3f\", $1/1000}")
	TBOX sleep "$SEC"
}

PROC_GONE() {
	NAME=$1
	LIMIT_MS=${2:-$PROC_GONE_TIMEOUT_MS}
	ELAPSED=0

	while pgrep -x "$NAME" >/dev/null 2>&1; do
		SLEEP_MS 100
		ELAPSED=$((ELAPSED + 100))
		[ "$ELAPSED" -ge "$LIMIT_MS" ] && return 1
	done

	return 0
}

GET_NODE_ID() {
	pw-dump |
		jq -r --arg pat "$1" '
		.[]
		| select(.type == "PipeWire:Interface:Node")
		| select((.info.props["media.class"] // "") | startswith("Audio/Sink"))
		| select((.info.props["node.name"] // "" | ascii_downcase)
		         | contains($pat | ascii_downcase))
		| .id
	' | head -n1
}

FADE_DOWN() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Fading sink volume down..."
	N=0
	while [ "$N" -lt 8 ]; do
		wpctl set-volume @DEFAULT_AUDIO_SINK@ 16%- || break
		SLEEP_MS 100
		N=$((N + 1))
	done

	wpctl set-volume @DEFAULT_AUDIO_SINK@ 0%
	wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
}

STOP_AUDIO_STACK() {
	for PROC in pipewire wireplumber; do
		LOG_INFO "$0" 0 "PIPEWIRE" "Stopping: %s (if running)" "$PROC"
		killall -q -15 "$PROC" 2>/dev/null || true
		PROC_GONE "$PROC" "$PROC_GONE_TIMEOUT_MS" || killall -q -9 "$PROC" 2>/dev/null || true
	done
}

REQUIRE_DBUS() {
	ELAPSED=0

	while [ ! -S "/run/dbus/system_bus_socket" ]; do
		SLEEP_MS 100
		ELAPSED=$((ELAPSED + 100))
		[ "$ELAPSED" -ge 3000 ] && break
	done

	if [ -S "/run/dbus/system_bus_socket" ]; then
		LOG_SUCCESS "$0" 0 "PIPEWIRE" "D-Bus socket is available"
	else
		LOG_WARN "$0" 0 "PIPEWIRE" "D-Bus not ready after 3s; proceeding"
	fi

	return 0
}

START_PIPEWIRE() {
	RUNTIME_DIR_INIT

	if ! pgrep -x "pipewire" >/dev/null 2>&1; then
		LOG_INFO "$0" 0 "PIPEWIRE" "Starting PipeWire (runtime: %s)" "$RUNTIME_DIR"
		XDG_RUNTIME_DIR="$RUNTIME_DIR" chrt -f 88 pipewire -c "$MUOS_SHARE_DIR/conf/pipewire.conf" &
	else
		LOG_WARN "$0" 0 "PIPEWIRE" "PipeWire already running"
	fi

	if ! pgrep -x "wireplumber" >/dev/null 2>&1; then
		LOG_INFO "$0" 0 "PIPEWIRE" "Starting WirePlumber..."
		XDG_RUNTIME_DIR="$RUNTIME_DIR" wireplumber &
	fi

	ELAPSED=0
	while ! SOCKET_READY; do
		SLEEP_MS "$FAST_READY_POLL_MS"
		ELAPSED=$((ELAPSED + FAST_READY_POLL_MS))
		[ "$ELAPSED" -ge "$FAST_READY_TIMEOUT_MS" ] && break
	done

	if SOCKET_READY; then
		LOG_SUCCESS "$0" 0 "PIPEWIRE" "Socket responsive at %s" "$RUNTIME_SOCK"
		return 0
	fi

	LOG_ERROR "$0" 0 "PIPEWIRE" "Not responsive after %dms (dir=%s)\n\tps: %s\n\tls: %s" \
		"$FAST_READY_TIMEOUT_MS" \
		"$RUNTIME_DIR" \
		"$(ps | grep -E 'pipewire|wireplumber' | grep -v grep)" \
		"$(ls -l "$RUNTIME_DIR" 2>/dev/null || printf 'n/a')"
	return 1
}

FINALISE_AUDIO() {
	ELAPSED=0
	while :; do
		if pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink"; then
			INTERNAL_NODE_ID=$(GET_NODE_ID "$(GET_VAR "device" "audio/pf_internal")")
			EXTERNAL_NODE_ID=$(GET_NODE_ID "$(GET_VAR "device" "audio/pf_external")")

			CONSOLE_MODE="$(GET_VAR "config" "boot/device_mode")"
			DEFAULT_NODE_ID=""

			if [ "$CONSOLE_MODE" -eq 1 ]; then
				DEFAULT_NODE_ID=$EXTERNAL_NODE_ID
				if [ "$(GET_VAR "config" "settings/hdmi/audio")" -eq 1 ]; then
					DEFAULT_NODE_ID=$INTERNAL_NODE_ID
				fi
			else
				DEFAULT_NODE_ID=$INTERNAL_NODE_ID
			fi

			if [ -n "$DEFAULT_NODE_ID" ]; then
				LOG_INFO "$0" 0 "PIPEWIRE" "Setting default node to ID: %s" "$DEFAULT_NODE_ID"
				wpctl set-default "$DEFAULT_NODE_ID"

				case "$(GET_VAR "config" "settings/advanced/volume")" in
					loud) VOLUME="$(GET_VAR "device" "audio/max")" ;;
					soft) VOLUME="35" ;;
					silent) VOLUME="0" ;;
					*) VOLUME="$(GET_VAR "config" "settings/general/volume")" ;;
				esac

				if [ "$CONSOLE_MODE" -eq 1 ]; then
					if [ "$(GET_VAR "config" "settings/advanced/overdrive")" -eq 1 ]; then
						wpctl set-volume @DEFAULT_AUDIO_SINK@ 200%
					else
						wpctl set-volume @DEFAULT_AUDIO_SINK@ 100%
					fi
				else
					/opt/muos/script/device/audio.sh "$VOLUME"
				fi

				wpctl set-mute @DEFAULT_AUDIO_SINK@ 0

				LOG_SUCCESS "$0" 0 "PIPEWIRE" "Audio finalised (node + volume)"
				return 0
			fi

			LOG_WARN "$0" 0 "PIPEWIRE" "Desired node not found yet"
			return 1
		fi

		SLEEP_MS "$SINK_DISCOVERY_POLL_MS"
		ELAPSED=$((ELAPSED + SINK_DISCOVERY_POLL_MS))
		[ "$ELAPSED" -ge "$SINK_DISCOVERY_TIMEOUT_MS" ] && break
	done

	LOG_ERROR "$0" 0 "PIPEWIRE" "Timeout waiting for PipeWire sinks"
	return 1
}

DO_START() {
	LOG_INFO "$0" 0 "PIPEWIRE" "D-Bus requirement checking"
	REQUIRE_DBUS || true

	LOG_INFO "$0" 0 "PIPEWIRE" "Launching PipeWire + WirePlumber"
	! START_PIPEWIRE && exit 1

	LOG_INFO "$0" 0 "PIPEWIRE" "Finalising audio setup"
	! FINALISE_AUDIO && exit 1

	AUDIO_CONTROL="$(GET_VAR "device" "audio/control")"
	AUDIO_VOL_PCT="$(GET_VAR "device" "audio/volume")"
	amixer -c 0 sset "$AUDIO_CONTROL" "${AUDIO_VOL_PCT}%" unmute >/dev/null 2>&1

	LOG_SUCCESS "$0" 0 "PIPEWIRE" "Audio is now ready"
	SET_VAR "device" "audio/ready" "1"
}

DO_STOP() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Audio shutdown sequence..."
	FADE_DOWN

	STOP_AUDIO_STACK
	SET_VAR "device" "audio/ready" "0"
	LOG_SUCCESS "$0" 0 "PIPEWIRE" "Audio shutdown complete"
}

case "$ACTION" in
	start) DO_START ;;
	stop) DO_STOP ;;
	*)
		printf "Usage: %s {start|stop}\n" "$0"
		exit 1
		;;
esac
