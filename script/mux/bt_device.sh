#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "BTDEVICE" "Bluetooth device management starting"

BT_DIR="$MUOS_CONF_GLOBAL/bluetooth"
BT_PAIRED="$BT_DIR/paired"

mkdir -p "$BT_DIR"

DO_LIST() {
	LOG_INFO "$0" 0 "BTDEVICE" "Listing paired Bluetooth devices"

	CONNECTED_MACS=$(bluetoothctl devices Connected 2>/dev/null | awk '{ print $2 }')

	TMP_BT_PAIR="$BT_DIR/paired.tmp.$$"
	: >"$TMP_BT_PAIR"

	bluetoothctl devices Paired 2>/dev/null | while IFS= read -r LINE; do
		# Format: "Device AA:BB:CC:DD:EE:FF Device Name"
		MAC=$(printf "%s" "$LINE" | awk '{ print $2 }')
		NAME=$(printf "%s" "$LINE" | cut -d' ' -f3-)
		[ -z "$MAC" ] && continue
		[ -z "$NAME" ] && NAME="$MAC"

		CONNECTED=0
		if printf "%s\n" "$CONNECTED_MACS" | grep -qxF "$MAC" 2>/dev/null; then
			CONNECTED=1
		fi

		printf "%s %d %s\n" "$MAC" "$CONNECTED" "$NAME" >>"$TMP_BT_PAIR"
	done

	mv -f "$TMP_BT_PAIR" "$BT_PAIRED"
	LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Paired device list written to '%s'" "$BT_PAIRED")"
}

DO_CONNECT() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for connect"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Connecting to '%s'" "$MAC")"

	if bluetoothctl connect "$MAC" >/dev/null 2>&1; then
		LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Connected to '%s'" "$MAC")"
	else
		LOG_WARN "$0" 0 "BTDEVICE" "$(printf "Connection to '%s' may have failed" "$MAC")"
	fi
}

DO_DISCONNECT() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for disconnect"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Disconnecting from '%s'" "$MAC")"

	if bluetoothctl disconnect "$MAC" >/dev/null 2>&1; then
		LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Disconnected from '%s'" "$MAC")"
	else
		LOG_WARN "$0" 0 "BTDEVICE" "$(printf "Disconnect from '%s' may have failed" "$MAC")"
	fi
}

DO_FORGET() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for forget"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Forgetting device '%s'" "$MAC")"
	bluetoothctl remove "$MAC" >/dev/null 2>&1
	LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Device '%s' removed" "$MAC")"
}

DO_INFO() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for info"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Fetching info for '%s'" "$MAC")"

	BT_INFO_FILE="$BT_DIR/device_info"
	BT_RAW=$(bluetoothctl info "$MAC" 2>/dev/null)

	{
		NAME=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tName:/ { print $2; exit }')
		[ -z "$NAME" ] && NAME="$MAC"
		printf "Name: %s\n" "$NAME"

		ICON=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tIcon:/ { print $2; exit }')
		[ -n "$ICON" ] && printf "Type: %s\n" "$ICON"

		RSSI=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tRSSI:/ { print $2; exit }')
		[ -n "$RSSI" ] && printf "Signal: %s dBm\n" "$RSSI"

		CONNECTED=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tConnected:/ { print $2; exit }')
		[ -n "$CONNECTED" ] && printf "Connected: %s\n" "$CONNECTED"

		# Somehow get battery? upower?
		#BATTERY=""
		#[ -n "$BATTERY" ] && printf "Battery: %s\n" "$BATTERY"
	} >"$BT_INFO_FILE"

	LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Device info written to '%s'" "$BT_INFO_FILE")"
}

DO_AUTOCONNECT() {
	AUTOCONNECT=$(GET_VAR "config" "bluetooth/autoconnect")

	if [ "${AUTOCONNECT:-0}" -ne 1 ]; then
		LOG_INFO "$0" 0 "BTDEVICE" "Auto-connect disabled - skipping"
		return 0
	fi

	LOG_INFO "$0" 0 "BTDEVICE" "Auto-connecting to trusted paired devices"

	bluetoothctl devices Paired 2>/dev/null | while IFS= read -r LINE; do
		MAC=$(printf "%s" "$LINE" | awk '{ print $2 }')
		[ -z "$MAC" ] && continue
		LOG_DEBUG "$0" 0 "BTDEVICE" "$(printf "Auto-connecting to '%s'" "$MAC")"
		bluetoothctl connect "$MAC" >/dev/null 2>&1 &
	done

	LOG_SUCCESS "$0" 0 "BTDEVICE" "Auto-connect sequence initiated"
}

case "${1:-}" in
	list) DO_LIST ;;
	connect) DO_CONNECT "$2" ;;
	disconnect) DO_DISCONNECT "$2" ;;
	forget) DO_FORGET "$2" ;;
	info) DO_INFO "$2" ;;
	autoconnect) DO_AUTOCONNECT ;;
	*)
		printf "Usage: %s {list|connect <mac>|disconnect <mac>|forget <mac>|info <mac>|autoconnect}\n" "$0"
		exit 1
		;;
esac
