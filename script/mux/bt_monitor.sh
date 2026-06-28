#!/bin/sh

. /opt/muos/script/var/func.sh

BT_DIR="$MUOS_CONF_GLOBAL/bluetooth"
SCRIPT_DIR="$(dirname "$0")"
MONITOR_PID_FILE="$MUOS_RUN_DIR/bt_monitor.pid"

mkdir -p "$BT_DIR"

IS_AUDIO_DEVICE() {
	MAC="$1"
	MAC_CLEAN=$(printf "%s" "$MAC" | tr ':' '_')
	STORED_TYPE=$(cat "$BT_DIR/type_$MAC_CLEAN" 2>/dev/null)

	if [ -n "$STORED_TYPE" ]; then
		case "$STORED_TYPE" in audio-*) return 0 ;; esac
		return 1
	fi

	BT_ICON=$(bluetoothctl info "$MAC" 2>/dev/null | awk -F': ' '/^\tIcon:/ { print $2; exit }')
	case "$BT_ICON" in audio-*) return 0 ;; esac
	return 1
}

HANDLE_DISCONNECT() {
	MAC="$1"
	LOG_INFO "$0" 0 "BTMONITOR" "$(printf "Device '%s' disconnected" "$MAC")"

	# Revert audio routing to the built-in sink when an audio device drops so a
	# headset powering off on idle does not leave audio pointed at something dead
	IS_AUDIO_DEVICE "$MAC" && "$SCRIPT_DIR/audio_sink.sh" set-builtin >/dev/null 2>&1 &

	# Refresh the managed list so the frontend reflects the new connected state
	"$SCRIPT_DIR/bt_device.sh" list >/dev/null 2>&1 &
}

HANDLE_CONNECT() {
	MAC="$1"
	LOG_INFO "$0" 0 "BTMONITOR" "$(printf "Device '%s' connected" "$MAC")"

	# Route anything audio to the device if it reconnected on its own
	IS_AUDIO_DEVICE "$MAC" && "$SCRIPT_DIR/audio_sink.sh" set-bt "$MAC" >/dev/null 2>&1 &

	"$SCRIPT_DIR/bt_device.sh" list >/dev/null 2>&1 &
}

DO_RUN() {
	printf "%s" "$$" >"$MONITOR_PID_FILE"
	trap 'rm -f "$MONITOR_PID_FILE"' EXIT

	LOG_INFO "$0" 0 "BTMONITOR" "Bluetooth connection monitor active"

	{
		printf "agent off\n"
		while :; do sleep 86400; done
	} | bluetoothctl 2>/dev/null | while IFS= read -r LINE; do
		case "$LINE" in
			*"Device "*"Connected: no"*)
				MAC=$(printf "%s" "$LINE" | sed -n 's/.*Device \([0-9A-Fa-f:]\{17\}\).*/\1/p')
				[ -n "$MAC" ] && HANDLE_DISCONNECT "$MAC"
				;;
			*"Device "*"Connected: yes"*)
				MAC=$(printf "%s" "$LINE" | sed -n 's/.*Device \([0-9A-Fa-f:]\{17\}\).*/\1/p')
				[ -n "$MAC" ] && HANDLE_CONNECT "$MAC"
				;;
		esac
	done
}

DO_START() {
	if [ -f "$MONITOR_PID_FILE" ]; then
		OLD_PID=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
		if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
			LOG_INFO "$0" 0 "BTMONITOR" "$(printf "Monitor already running (PID %s)" "$OLD_PID")"
			return 0
		fi
		rm -f "$MONITOR_PID_FILE"
	fi

	setsid "$0" run >/dev/null 2>&1 &
	LOG_SUCCESS "$0" 0 "BTMONITOR" "Bluetooth connection monitor started"
}

DO_STOP() {
	[ -f "$MONITOR_PID_FILE" ] || return 0

	PID=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
	if [ -n "$PID" ]; then
		kill -- -"$PID" 2>/dev/null || kill "$PID" 2>/dev/null
	fi

	rm -f "$MONITOR_PID_FILE"
	LOG_SUCCESS "$0" 0 "BTMONITOR" "Bluetooth connection monitor stopped"
}

case "${1:-}" in
	start) DO_START ;;
	stop) DO_STOP ;;
	run) DO_RUN ;;
	restart)
		DO_STOP
		DO_START
		;;
	*)
		printf "Usage: %s {start|stop|run|restart}\n" "$0"
		exit 1
		;;
esac
