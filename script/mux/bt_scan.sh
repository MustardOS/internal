#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "BTSCAN" "Bluetooth scan manager starting"

BT_DIR="$MUOS_CONF_GLOBAL/bluetooth"
BT_SCAN="$BT_DIR/scan"
SCAN_TIMEOUT=10 # Is this enough?

mkdir -p "$BT_DIR"

DO_LIST() {
	LOG_INFO "$0" 0 "BTSCAN" "$(printf "Scanning for nearby Bluetooth devices (%ss)" "$SCAN_TIMEOUT")"

	# Apparently it needs to be powered on even though it is... powered on?
	bluetoothctl power on >/dev/null 2>&1

	(
		printf "scan on\n"
		sleep "$SCAN_TIMEOUT"
		printf "scan off\n"
	) | bluetoothctl >/dev/null 2>&1

	TMP_BT_SCAN="$BT_DIR/scan.tmp.$$"
	: >"$TMP_BT_SCAN"

	bluetoothctl devices 2>/dev/null | while IFS= read -r LINE; do
		# Format: "Device AA:BB:CC:DD:EE:FF Device Name"
		MAC=$(printf "%s" "$LINE" | awk '{ print $2 }')
		NAME=$(printf "%s" "$LINE" | cut -d' ' -f3-)
		[ -z "$MAC" ] && continue
		[ -z "$NAME" ] && NAME="$MAC"
		printf "%s %s\n" "$MAC" "$NAME" >>"$TMP_BT_SCAN"
	done

	mv -f "$TMP_BT_SCAN" "$BT_SCAN"

	COUNT=$(wc -l <"$BT_SCAN" 2>/dev/null)
	LOG_SUCCESS "$0" 0 "BTSCAN" "$(printf "Found %s device(s); results written to '%s'" "${COUNT:-0}" "$BT_SCAN")"
}

DO_CONNECT() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTSCAN" "No MAC address provided for connect"
		exit 1
	}

	LOG_INFO "$0" 0 "BTSCAN" "$(printf "Pairing and connecting to '%s'" "$MAC")"

	bluetoothctl pair "$MAC" >/dev/null 2>&1
	bluetoothctl trust "$MAC" >/dev/null 2>&1

	if bluetoothctl connect "$MAC" >/dev/null 2>&1; then
		LOG_SUCCESS "$0" 0 "BTSCAN" "$(printf "Connected to '%s'" "$MAC")"
	else
		LOG_WARN "$0" 0 "BTSCAN" "$(printf "Connection to '%s' may have failed" "$MAC")"
	fi
}

DO_INFO() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTSCAN" "No MAC address provided for info"
		exit 1
	}

	LOG_INFO "$0" 0 "BTSCAN" "$(printf "Fetching info for '%s'" "$MAC")"

	BT_INFO="$MUOS_RUN_DIR/bt_info"
	BT_RAW=$(bluetoothctl info "$MAC" 2>/dev/null)

	if [ -z "$BT_RAW" ]; then
		printf "Address: %s\nNo additional information available.\n" "$MAC" >"$BT_INFO"
		return 0
	fi

	{
		printf "Address: %s\n" "$MAC"

		ICON=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tIcon:/ { print $2; exit }')
		[ -n "$ICON" ] && printf "Type:    %s\n" "$ICON"

		RSSI=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tRSSI:/ { print $2; exit }')
		[ -n "$RSSI" ] && printf "Signal:  %s dBm\n" "$RSSI"

		PAIRED=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tPaired:/ { print $2; exit }')
		[ -n "$PAIRED" ] && printf "Paired:  %s\n" "$PAIRED"

		TRUSTED=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tTrusted:/ { print $2; exit }')
		[ -n "$TRUSTED" ] && printf "Trusted: %s\n" "$TRUSTED"

		CONNECTED=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tConnected:/ { print $2; exit }')
		[ -n "$CONNECTED" ] && printf "Connected: %s\n" "$CONNECTED"
	} >"$BT_INFO"

	LOG_SUCCESS "$0" 0 "BTSCAN" "$(printf "Device info written to '%s'" "$BT_INFO")"
}

case "${1:-}" in
	list) DO_LIST ;;
	connect) DO_CONNECT "$2" ;;
	info) DO_INFO "$2" ;;
	*)
		printf "Usage: %s {list|connect <mac>|info <mac>}\n" "$0"
		exit 1
		;;
esac
