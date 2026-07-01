#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "BTDIAG" "Bluetooth diagnostic starting"

BT_DIR="$MUOS_CONF_GLOBAL/bluetooth"
BT_PAIRED="$BT_DIR/paired"
MONITOR_PID_FILE="$MUOS_RUN_DIR/bt_monitor.pid"
BT_DAEMON="/usr/libexec/bluetooth/bluetoothd"

mkdir -p "$BT_DIR"

PASS="[ OK ]"
FAIL="[FAIL]"
INFO="[INFO]"
WARN="[WARN]"

SECTION() {
	printf "\n--- %s ---\n" "$1"
}

CHECK() {
	printf "  %s  %s\n" "$1" "$2"
}

DETAIL() {
	printf "         %s\n" "$1"
}

DO_RUN() {
	SECTION "Hardware"
	LOG_INFO "$0" 0 "BTDIAG" "Checking hardware"

	HCI_NAME=""
	for D in /sys/class/bluetooth/hci*; do
		[ -d "$D" ] && HCI_NAME=$(basename "$D") && break
	done

	if [ -n "$HCI_NAME" ]; then
		CHECK "$PASS" "HCI adapter present: $HCI_NAME"
	else
		CHECK "$FAIL" "No HCI adapter found in /sys/class/bluetooth - hardware missing or module not loaded"
	fi

	if command -v rfkill >/dev/null 2>&1; then
		RFKILL_OUT=$(rfkill list bluetooth 2>/dev/null)
		if [ -z "$RFKILL_OUT" ]; then
			CHECK "$WARN" "rfkill: no bluetooth devices listed"
		else
			CURRENT_DEV=""
			printf "%s\n" "$RFKILL_OUT" | while IFS= read -r LINE; do
				case "$LINE" in
					[0-9]*:*)
						CURRENT_DEV=$(printf "%s" "$LINE" | awk -F': ' '{print $2}')
						;;
					*"Soft blocked: yes"*)
						CHECK "$FAIL" "rfkill soft-blocked: ${CURRENT_DEV:-(unknown)} - run: rfkill unblock bluetooth"
						;;
					*"Soft blocked: no"*)
						CHECK "$PASS" "rfkill soft-block clear: ${CURRENT_DEV:-(unknown)}"
						;;
					*"Hard blocked: yes"*)
						CHECK "$FAIL" "rfkill hard-blocked: ${CURRENT_DEV:-(unknown)} (hardware switch?)"
						;;
				esac
			done
		fi
	else
		CHECK "$INFO" "rfkill not available - skipping block check"
	fi

	if command -v hciconfig >/dev/null 2>&1; then
		HCI_OUT=$(hciconfig 2>/dev/null)
		if [ -n "$HCI_OUT" ]; then
			CHECK "$PASS" "hciconfig reports adapter(s):"
			printf "%s\n" "$HCI_OUT" | while IFS= read -r LINE; do
				DETAIL "$LINE"
			done
		else
			CHECK "$FAIL" "hciconfig reports no adapters"
		fi
	else
		CHECK "$INFO" "hciconfig not available"
	fi

	BOARD_NAME=$(GET_VAR "device" "board/name")
	CHECK "$INFO" "Board: ${BOARD_NAME:-unknown}"
	case "$BOARD_NAME" in
		rg-vita*)
			DETAIL "Board variant has no Bluetooth attachment step"
			;;
		rg*)
			if grep -q "^rtl_btlpm " /proc/modules 2>/dev/null; then
				CHECK "$PASS" "rtl_btlpm kernel module loaded"
			else
				CHECK "$FAIL" "rtl_btlpm kernel module NOT loaded (required for rg* boards)"
			fi
			;;
		tui*)
			if grep -q "xradio" /proc/modules 2>/dev/null; then
				CHECK "$PASS" "xradio module loaded"
			else
				CHECK "$WARN" "xradio module may not be loaded"
			fi
			;;
	esac

	SECTION "BlueZ daemon"
	LOG_INFO "$0" 0 "BTDIAG" "Checking BlueZ daemon"

	if [ -x "$BT_DAEMON" ]; then
		CHECK "$PASS" "bluetoothd binary found: $BT_DAEMON"
	else
		CHECK "$FAIL" "bluetoothd binary NOT found at $BT_DAEMON - BlueZ not installed"
	fi

	if pgrep -x bluetoothd >/dev/null 2>&1; then
		CHECK "$PASS" "bluetoothd is running"
	else
		CHECK "$FAIL" "bluetoothd is NOT running - start with S75bluetooth.sh start"
	fi

	if pgrep -x dbus-daemon >/dev/null 2>&1; then
		CHECK "$PASS" "dbus-daemon is running"
	else
		CHECK "$FAIL" "dbus-daemon is NOT running - bluetoothd requires dbus"
	fi

	if [ -d /var/lib/bluetooth ]; then
		CHECK "$PASS" "/var/lib/bluetooth exists"
	else
		CHECK "$WARN" "/var/lib/bluetooth missing - will be created on first bluetoothd start"
	fi

	if command -v hciconfig >/dev/null 2>&1 && [ -n "$HCI_NAME" ]; then
		if hciconfig "$HCI_NAME" 2>/dev/null | grep -q "UP "; then
			CHECK "$PASS" "HCI adapter is UP"
		else
			CHECK "$WARN" "HCI adapter is DOWN - bluetoothd should bring it up on start"
		fi
	fi

	BT_SHOW=$(timeout 3 bluetoothctl show 2>/dev/null)
	if [ -n "$BT_SHOW" ]; then
		CHECK "$PASS" "bluetoothctl responded"

		POWERED=$(printf "%s" "$BT_SHOW" | awk -F': ' '/^\tPowered:/ {print $2; exit}')
		if [ "$POWERED" = "yes" ]; then
			CHECK "$PASS" "Adapter powered on"
		else
			CHECK "$FAIL" "Adapter NOT powered on - run: bluetoothctl power on"
		fi

		DISCOVERABLE=$(printf "%s" "$BT_SHOW" | awk -F': ' '/^\tDiscoverable:/ {print $2; exit}')
		CHECK "$INFO" "Discoverable: ${DISCOVERABLE:-unknown}"

		DISCOVERING=$(printf "%s" "$BT_SHOW" | awk -F': ' '/^\tDiscovering:/ {print $2; exit}')
		CHECK "$INFO" "Discovering:  ${DISCOVERING:-unknown}"

		ADDR=$(printf "%s" "$BT_SHOW" | awk -F': ' '/^\tAddress:/ {print $2; exit}')
		[ -n "$ADDR" ] && CHECK "$INFO" "Adapter address: $ADDR"
	else
		CHECK "$FAIL" "bluetoothctl did not respond - daemon may be stuck or not ready"
	fi

	SECTION "Connection monitor"
	LOG_INFO "$0" 0 "BTDIAG" "Checking bt_monitor"

	if [ -f "$MONITOR_PID_FILE" ]; then
		MON_PID=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
		if [ -n "$MON_PID" ] && kill -0 "$MON_PID" 2>/dev/null; then
			CHECK "$PASS" "bt_monitor running (PID $MON_PID)"
		else
			CHECK "$WARN" "bt_monitor PID file exists but process is dead (stale PID $MON_PID)"
		fi
	else
		CHECK "$WARN" "bt_monitor PID file not found - monitor may not be running"
	fi

	SECTION "Configuration"

	AUTOCONNECT=$(GET_VAR "config" "bluetooth/autoconnect")
	if [ "${AUTOCONNECT:-0}" -eq 1 ]; then
		CHECK "$INFO" "Auto Connect: enabled"
	else
		CHECK "$INFO" "Auto Connect: disabled"
	fi

	SECTION "Paired devices"
	LOG_INFO "$0" 0 "BTDIAG" "Checking paired devices"

	if [ -f "$BT_PAIRED" ] && [ -s "$BT_PAIRED" ]; then
		PAIR_COUNT=$(wc -l <"$BT_PAIRED")
		CHECK "$INFO" "$PAIR_COUNT paired device(s) on record:"

		CONNECTED_MACS=$(timeout 5 bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')

		while IFS= read -r LINE; do
			MAC=$(printf "%s" "$LINE" | awk '{print $1}')
			NAME=$(printf "%s" "$LINE" | cut -d' ' -f2-)
			[ -z "$MAC" ] && continue

			BT_RAW=$(timeout 3 bluetoothctl info "$MAC" 2>/dev/null)

			IS_CONN="no"
			printf "%s\n" "$CONNECTED_MACS" | grep -qxF "$MAC" 2>/dev/null && IS_CONN="yes"

			IS_TRUSTED=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tTrusted:/ {print $2; exit}')
			IS_BLOCKED=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tBlocked:/ {print $2; exit}')
			BT_PAIRED_F=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tPaired:/ {print $2; exit}')

			STATUS=""
			[ "$IS_CONN" = "yes" ] && STATUS="${STATUS}connected "
			[ "${IS_TRUSTED:-no}" = "yes" ] && STATUS="${STATUS}trusted "
			[ "${IS_BLOCKED:-no}" = "yes" ] && STATUS="${STATUS}BLOCKED "
			[ "${BT_PAIRED_F:-no}" != "yes" ] && STATUS="${STATUS}not-paired-in-bluez "

			if [ -z "$BT_RAW" ]; then
				DETAIL "$MAC  $NAME  [not known to bluetoothd - may need re-pair]"
			elif [ "${IS_BLOCKED:-no}" = "yes" ]; then
				DETAIL "$MAC  $NAME  [${STATUS:-ok}]  <-- blocked: run: bluetoothctl unblock $MAC"
			else
				DETAIL "$MAC  $NAME  [${STATUS:-ok}]"
			fi
		done <"$BT_PAIRED"
	else
		CHECK "$INFO" "No paired devices on record"
	fi

	BZ_PAIRED=$(timeout 5 bluetoothctl devices Paired 2>/dev/null)
	if [ -n "$BZ_PAIRED" ]; then
		BZ_COUNT=$(printf "%s\n" "$BZ_PAIRED" | wc -l)
		CHECK "$INFO" "$BZ_COUNT device(s) paired in BlueZ:"
		printf "%s\n" "$BZ_PAIRED" | while IFS= read -r LINE; do
			DETAIL "$LINE"
		done
	else
		CHECK "$INFO" "No devices paired in BlueZ"
	fi

	SECTION "Blocked devices"
	LOG_INFO "$0" 0 "BTDIAG" "Checking for blocked devices"

	BZ_BLOCKED=$(timeout 5 bluetoothctl devices 2>/dev/null | while IFS= read -r LINE; do
		MAC=$(printf "%s" "$LINE" | awk '{print $2}')
		[ -z "$MAC" ] && continue
		INFO_OUT=$(timeout 2 bluetoothctl info "$MAC" 2>/dev/null)
		BLOCKED=$(printf "%s" "$INFO_OUT" | awk -F': ' '/^\tBlocked:/ {print $2; exit}')
		[ "$BLOCKED" = "yes" ] && printf "%s\n" "$LINE"
	done)

	if [ -n "$BZ_BLOCKED" ]; then
		CHECK "$WARN" "Blocked devices found (cannot connect until unblocked):"
		printf "%s\n" "$BZ_BLOCKED" | while IFS= read -r LINE; do
			MAC=$(printf "%s" "$LINE" | awk '{print $2}')
			DETAIL "$LINE  -- unblock: bluetoothctl unblock $MAC"
		done
	else
		CHECK "$PASS" "No blocked devices"
	fi

	SECTION "Active Bluetooth processes"
	LOG_INFO "$0" 0 "BTDIAG" "Checking active Bluetooth processes"

	for PROC in bluetoothd rtk_hciattach bt_monitor.sh bt_device.sh bt_scan.sh; do
		PIDS=$(pgrep -f "$PROC" 2>/dev/null | tr '\n' ' ')
		[ -n "$PIDS" ] && CHECK "$INFO" "$PROC running (PID: $PIDS)"
	done

	BTC_PIDS=$(pgrep -x bluetoothctl 2>/dev/null | tr '\n' ' ')
	if [ -n "$BTC_PIDS" ]; then
		CHECK "$WARN" "bluetoothctl instance(s) already running (PID: $BTC_PIDS) - may interfere with scan/connect"
	fi

	SECTION "Quick scan (5s)"
	LOG_INFO "$0" 0 "BTDIAG" "Running quick scan"

	if [ "$POWERED" = "yes" ]; then
		CHECK "$INFO" "Scanning for nearby devices..."
		SCAN_RAW=$(
			{
				printf "scan on\n"
				sleep 5
				printf "scan off\n"
			} | timeout 10 bluetoothctl 2>/dev/null
		)
		FOUND=$(printf "%s\n" "$SCAN_RAW" | grep -c "\[NEW\] Device" 2>/dev/null || true)
		if [ "${FOUND:-0}" -gt 0 ]; then
			CHECK "$PASS" "$(printf "%s device(s) discovered during scan:" "$FOUND")"
			printf "%s\n" "$SCAN_RAW" | grep "\[NEW\] Device" | while IFS= read -r LINE; do
				DETAIL "$LINE"
			done
		else
			CHECK "$WARN" "No new devices discovered during 5s scan"
			DETAIL "Check that the target device is in pairing or discover mode"
		fi
	else
		CHECK "$WARN" "Adapter not powered - skipping scan"
	fi

	printf "\n"

	LOG_SUCCESS "$0" 0 "BTDIAG" "Bluetooth diagnostic complete"
}

case "${1:-run}" in
	run) DO_RUN ;;
	*)
		printf "Usage: %s [run]\n" "$0"
		exit 1
		;;
esac
