#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "BTSCAN" "Bluetooth scan manager starting"

BT_DIR="$MUOS_CONF_GLOBAL/bluetooth"
BT_SCAN="$BT_DIR/scan"
BT_PAIRED="$BT_DIR/paired"
SCAN_TIMEOUT=10 # Is this enough?

mkdir -p "$BT_DIR"

# Oui oui monsieur
# https://www.linuxnet.ca/ieee/oui.html
OUI_LOOKUP() {
	OUI=$(printf "%s" "$1" | tr '[:lower:]' '[:upper:]' | tr -d ':' | cut -c1-6)
	OUI_FMT=$(printf "%s:%s:%s" \
		"$(printf "%s" "$OUI" | cut -c1-2)" \
		"$(printf "%s" "$OUI" | cut -c3-4)" \
		"$(printf "%s" "$OUI" | cut -c5-6)")

	DB="/opt/muos/share/conf/oui.txt"
	[ -f "$DB" ] || return 1

	VENDOR=$(grep -im1 "^$OUI_FMT" "$DB" | awk '/\(hex\)/{sub(/.*\(hex\)[[:space:]]*/,""); print}')
	[ -n "$VENDOR" ] && printf "%s" "$VENDOR" && return 0

	return 1
}

DO_LIST() {
	LOG_INFO "$0" 0 "BTSCAN" "$(printf "Scanning for nearby Bluetooth devices (%ss)" "$SCAN_TIMEOUT")"

	# Apparently it needs to be powered on even though it is... powered on?
	bluetoothctl power on >/dev/null 2>&1

	TMP_NAMES="$BT_DIR/scan_names.tmp.$$"
	: >"$TMP_NAMES"

	(
		printf "scan on\n"
		sleep "$SCAN_TIMEOUT"
		printf "scan off\n"
	) | bluetoothctl 2>/dev/null | while IFS= read -r LINE; do
		MAC=""
		NAME=""
		case "$LINE" in
			*"[NEW] Device "*)
				MAC=$(printf "%s" "$LINE" | awk '{print $3}')
				NAME=$(printf "%s" "$LINE" | cut -d' ' -f4-)
				;;
			*"[CHG] Device "*"Name: "*)
				MAC=$(printf "%s" "$LINE" | awk '{print $3}')
				NAME=$(printf "%s" "$LINE" | awk -F'Name: ' '{print $2}')
				;;
		esac
		[ -n "$MAC" ] && [ -n "$NAME" ] && [ "$NAME" != "$MAC" ] &&
			printf "%s\t%s\n" "$MAC" "$NAME" >>"$TMP_NAMES"
	done

	TMP_SPECIAL="$BT_DIR/scan_special.tmp.$$"
	TMP_NAMED="$BT_DIR/scan_named.tmp.$$"
	TMP_UNKNOWN="$BT_DIR/scan_unknown.tmp.$$"

	: >"$TMP_SPECIAL"
	: >"$TMP_NAMED"
	: >"$TMP_UNKNOWN"

	CONNECTED_MACS=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')
	TRUSTED_MACS=$(
		for ADAPTER_DIR in /var/lib/bluetooth/??:??:??:??:??:??/; do
			[ -d "$ADAPTER_DIR" ] || continue
			for DEVICE_DIR in "$ADAPTER_DIR"??:??:??:??:??:??/; do
				INFO="$DEVICE_DIR/info"
				[ -f "$INFO" ] || continue
				grep -q '^Trusted=true' "$INFO" 2>/dev/null || continue
				printf "%s\n" "$(basename "$DEVICE_DIR")"
			done
		done
	)

	bluetoothctl devices 2>/dev/null | while IFS= read -r LINE; do
		# Format: "Device AA:BB:CC:DD:EE:FF Device Name"
		MAC=$(printf "%s" "$LINE" | awk '{print $2}')
		NAME=$(printf "%s" "$LINE" | cut -d' ' -f3-)
		[ -z "$MAC" ] && continue

		# Skip paired, trusted, and connected devices
		grep -q "^$MAC " "$BT_PAIRED" 2>/dev/null && continue
		printf "%s\n" "$TRUSTED_MACS" | grep -qxF "$MAC" 2>/dev/null && continue
		printf "%s\n" "$CONNECTED_MACS" | grep -qxF "$MAC" 2>/dev/null && continue

		RESOLVED=$(awk -F'\t' -v mac="$MAC" '$1==mac{name=$2} END{if(name) print name}' "$TMP_NAMES" 2>/dev/null)
		[ -n "$RESOLVED" ] && NAME="$RESOLVED"

		case "$NAME" in
			"" | "$MAC" | \
				[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F] | \
				[0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F])
				VENDOR=$(OUI_LOOKUP "$MAC")
				printf "%s %s\n" "$MAC" "${VENDOR:-$MAC}" >>"$TMP_UNKNOWN"
				;;
			[A-Za-z0-9]*)
				printf "%s %s\n" "$MAC" "$NAME" >>"$TMP_NAMED"
				;;
			*)
				printf "%s %s\n" "$MAC" "$NAME" >>"$TMP_SPECIAL"
				;;
		esac
	done

	rm -f "$TMP_NAMES"

	TMP_BT_SCAN="$BT_DIR/scan.tmp.$$"
	{
		sort -k2 -f "$TMP_SPECIAL"
		sort -k2 -f "$TMP_NAMED"
		sort -k2 -f "$TMP_UNKNOWN"
	} >"$TMP_BT_SCAN"

	rm -f "$TMP_SPECIAL" "$TMP_NAMED" "$TMP_UNKNOWN"
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

		BT_ICON=$(bluetoothctl info "$MAC" 2>/dev/null | awk -F': ' '/^\tIcon:/ { print $2; exit }')
		case "$BT_ICON" in
			audio-*) "$(dirname "$0")/audio_sink.sh" set-bt "$MAC" & ;;
		esac
	else
		LOG_WARN "$0" 0 "BTSCAN" "$(printf "Connection to '%s' may have failed" "$MAC")"
	fi

	"$(dirname "$0")/bt_device.sh" list
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
