#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")

BT_DAEMON="/usr/libexec/bluetooth/bluetoothd"

HCI_PID="$MUOS_RUN_DIR/hciattach.pid"
BT_PID="$MUOS_RUN_DIR/bluetoothd.pid"

TIMEOUT=5000
INTERVAL=100

PROC_RUNNING() {
	pgrep -x "$1" >/dev/null 2>&1
}

HCI_READY() {
	[ -d "/sys/class/bluetooth/hci0" ]
}

BLUETOOTHD_READY() {
	bluetoothctl show >/dev/null 2>&1
}

WAIT_UNTIL() {
	COND_FN="$1"
	ELAPSED=0

	while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
		"$COND_FN" && return 0
		sleep 0.1
		ELAPSED=$((ELAPSED + INTERVAL))
	done

	return 1
}

STOP_PROC() {
	NAME="$1"
	PIDFILE="$2"

	if [ -r "$PIDFILE" ]; then
		PID=$(cat "$PIDFILE" 2>/dev/null)
		if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
			LOG_DEBUG "$0" 0 "BLUETOOTH" "$(printf "Stopping '%s' (PID: %s)" "$NAME" "$PID")"
			kill -15 "$PID" 2>/dev/null
			sleep 0.5
			kill -0 "$PID" 2>/dev/null && kill -9 "$PID" 2>/dev/null
		fi
		rm -f "$PIDFILE"
	elif PROC_RUNNING "$NAME"; then
		LOG_DEBUG "$0" 0 "BLUETOOTH" "$(printf "Stopping '%s' by name" "$NAME")"
		pkill -15 -x "$NAME" 2>/dev/null
	fi
}

DO_START() {
	case "$BOARD_NAME" in
		rg-vita*) ;; # Add this at some stage...
		rg*)
			NET_NAME=$(GET_VAR "device" "network/name")
			HAS_NETWORK=$(GET_VAR "device" "board/network")
			if [ "${HAS_NETWORK:-0}" -ne 0 ] && [ -n "$NET_NAME" ] && ! grep -q "^$NET_NAME " /proc/modules 2>/dev/null; then
				LOG_INFO "$0" 0 "BLUETOOTH" "Loading network module required..."
				/opt/muos/script/init/async/S02network.sh load
			fi
			LOG_INFO "$0" 0 "BLUETOOTH" "Attaching Realtek HCI (rg variant)"
			modprobe /lib/modules/4.9.170/kernel/drivers/bluetooth/rtl_btlpm.ko
			rtk_hciattach -n -s 115200 /dev/ttyS1 rtk_h5 >/dev/null 2>&1 &
			printf "%s" "$!" >"$HCI_PID"
			;;
		tui*)
			LOG_INFO "$0" 0 "BLUETOOTH" "Attaching Realtek HCI (tui/xradio variant)"
			rtk_hciattach -n -s 115200 ttyS1 xradio >/dev/null 2>&1 &
			printf "%s" "$!" >"$HCI_PID"
			;;
		*)
			LOG_INFO "$0" 0 "BLUETOOTH" "$(printf "No Bluetooth HCI attachment needed for board '%s'" "$BOARD_NAME")"
			return 0
			;;
	esac

	LOG_INFO "$0" 0 "BLUETOOTH" "Waiting for HCI device to become ready"
	if ! WAIT_UNTIL HCI_READY; then
		LOG_WARN "$0" 0 "BLUETOOTH" "HCI device did not appear within timeout"
		return 1
	fi

	LOG_SUCCESS "$0" 0 "BLUETOOTH" "HCI device ready"

	if [ ! -x "$BT_DAEMON" ]; then
		LOG_WARN "$0" 0 "BLUETOOTH" "$(printf "bluetoothd not found at '%s' - skipping" "$BT_DAEMON")"
		return 0
	fi

	if PROC_RUNNING bluetoothd; then
		LOG_WARN "$0" 0 "BLUETOOTH" "bluetoothd already running"
		return 0
	fi

	mkdir -p /var/lib/bluetooth

	LOG_INFO "$0" 0 "BLUETOOTH" "Starting bluetoothd"
	"$BT_DAEMON" -n -d >/dev/null 2>&1 &
	printf "%s" "$!" >"$BT_PID"

	LOG_SUCCESS "$0" 0 "BLUETOOTH" "Bluetooth stack started"

	(WAIT_UNTIL BLUETOOTHD_READY && sleep 2 && /opt/muos/script/mux/bt_device.sh list && /opt/muos/script/mux/bt_device.sh autoconnect) &
}

DO_STOP() {
	LOG_INFO "$0" 0 "BLUETOOTH" "Stopping Bluetooth stack"

	STOP_PROC "bluetoothd" "$BT_PID"
	STOP_PROC "rtk_hciattach" "$HCI_PID"

	LOG_SUCCESS "$0" 0 "BLUETOOTH" "Bluetooth stack stopped"
}

case "${1:-}" in
	start) DO_START ;;
	stop) DO_STOP ;;
	restart)
		DO_STOP
		DO_START
		;;
	*)
		printf "Usage: %s {start|stop|restart}\n" "$0" >&2
		exit 1
		;;
esac
